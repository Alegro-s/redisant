from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import Alert, AlertSeverity, Message, MessageFeatures, StyleProfile, User, UserRole
from app.services.ai_client import analyze_with_external_ai
from app.services.alert_delivery import deliver_alert
from app.services.alert_policy import should_emit_alert
from app.services.detection.phishing_signals import evaluate_phishing_signals
from app.services.detection.pipeline import run_pipeline
from app.services.inference_gateway import enrich_with_gateway, gray_zone_judge
from app.services.messages import get_admin_user_ids
from app.services.ml_storage import (
    AnalysisTimer,
    apply_features_from_analysis,
    auto_training_label,
    save_analysis_run,
)

def _enrich_metadata(db: Session, message: Message, metadata: dict) -> dict:
    meta = dict(metadata)
    meta.setdefault("channel", message.channel.value if message.channel else "")
    if message.sender_id:
        sender = db.get(User, message.sender_id)
        if sender:
            meta["user_name"] = sender.username
            meta["username"] = sender.username
            meta["user_role"] = sender.role.value
            meta["sender_id"] = sender.id
            style = db.query(StyleProfile).filter(StyleProfile.user_id == sender.id).first()
            if style:
                meta["style_traits"] = style.traits
                meta["style_reference"] = style.reference_vector
            from sqlalchemy import func

            from app.db.models import Message as Msg

            channels = (
                db.query(Msg.channel, func.count(Msg.id))
                .filter(Msg.sender_id == sender.id)
                .group_by(Msg.channel)
                .all()
            )
            if len(channels) > 1:
                meta["channel_switch_24h"] = True
            corpus = (
                db.query(Message.body)
                .filter(Message.sender_id == sender.id, Message.body.isnot(None))
                .order_by(desc(Message.created_at))
                .limit(120)
                .all()
            )
            samples = [row[0].strip() for row in corpus if row[0] and len(row[0].strip()) > 2]
            if samples:
                meta["corpus_samples"] = samples
    if message.impersonated_user_id:
        imp = db.get(User, message.impersonated_user_id)
        if imp:
            meta["impersonates_username"] = imp.username
    return meta

from app.services.message_crypto import resolve_message_plaintext

def analyze_message(
    db: Session,
    message: Message,
    *,
    plaintext: str | None = None,
    local_only: bool = False,
) -> MessageFeatures | None:
    if plaintext is None:
        plaintext = resolve_message_plaintext(message)
    text = (plaintext or "").strip()
    if not text:
        message.analysis_status = "error"
        db.add(message)
        db.commit()
        return None

    settings = get_settings()
    metadata = _enrich_metadata(db, message, message.metadata_ or {})
    voice_extras = metadata.get("voice_analysis")
    metadata["preliminary_risk"] = 0.0
    request_payload = {"text": text, "metadata": {k: v for k, v in metadata.items() if k != "corpus_samples"}}

    with AnalysisTimer() as timer:
        local = run_pipeline(text, metadata, db=db, voice_extras=voice_extras, skip_remote=local_only)
        inline_timeout = min(8, settings.ai_service_timeout)
        ai_result = None if local_only else analyze_with_external_ai(text, metadata, timeout=inline_timeout)
        gw_enrich = None
        if not local_only:
            gw_enrich = enrich_with_gateway(
                text,
                metadata,
                local,
                min_risk=settings.lm_studio_min_risk,
            )
            if not gw_enrich:
                gw_enrich = gray_zone_judge(text, metadata, local)

    gw_ms = gw_enrich.inference_ms if gw_enrich else 0

    if ai_result and ai_result.risk_score >= local["risk_score"]:
        message.analysis_source = "external_ai"
        risk = ai_result.risk_score
        explanation = ai_result.explanation_ru
        title = ai_result.title_ru
        alert_type = ai_result.alert_type
        feature_vector = {**ai_result.feature_vector, "source": "external_ai"}
        style_sim = ai_result.style_similarity
        ai_score = ai_result.ai_score
        meta_score = ai_result.metadata_anomaly_score
        layer_hits = ai_result.layer_hits
        model_name = "external_ai"
        model_version = (ai_result.feature_vector or {}).get("model_version")
        embedding = (ai_result.feature_vector or {}).get("embedding")
    elif gw_enrich:
        message.analysis_source = "detection_v2+gateway"
        risk = local["risk_score"]
        if gw_enrich.verdict and gw_enrich.verdict.get("confidence", 0) >= 0.55:
            risk = min(1.0, max(risk, float(gw_enrich.verdict.get("confidence", risk))))
        explanation = gw_enrich.explanation_ru
        title = gw_enrich.title_ru
        alert_type = gw_enrich.alert_type or local["alert_type"]
        feature_vector = {
            **local["feature_vector"],
            "source": "detection_v2+gateway",
            "gateway_model": gw_enrich.model,
            "gateway_ms": gw_enrich.inference_ms,
            "verdict": gw_enrich.verdict,
        }
        style_sim = local["style_similarity"]
        ai_score = local["ai_score"]
        meta_score = local["metadata_anomaly_score"]
        layer_hits = gw_enrich.layer_hits or local["layer_hits"]
        model_name = gw_enrich.model
        model_version = "gateway"
        embedding = None
    else:
        message.analysis_source = "detection_v2"
        risk = local["risk_score"]
        explanation = local["explanation_ru"]
        title = local["title_ru"]
        alert_type = local["alert_type"]
        feature_vector = local["feature_vector"]
        style_sim = local["style_similarity"]
        ai_score = local["ai_score"]
        meta_score = local["metadata_anomaly_score"]
        layer_hits = local["layer_hits"]
        model_name = "detection_v2"
        model_version = "2.0.0"
        embedding = None

    raw_response = {
        "explanation_ru": explanation,
        "title_ru": title,
        "alert_type": alert_type,
        "layer_hits": layer_hits,
    }

    message.analysis_status = "done"
    db.add(message)

    features = db.query(MessageFeatures).filter(MessageFeatures.message_id == message.id).first()
    if not features:
        features = MessageFeatures(message_id=message.id)
        db.add(features)
    features.feature_vector = feature_vector
    features.style_similarity = style_sim
    features.ai_score = ai_score
    features.metadata_anomaly_score = meta_score
    features.risk_score = risk
    apply_features_from_analysis(
        db,
        message,
        features,
        model_name=model_name,
        model_version=model_version,
        layer_hits=layer_hits,
        raw_response=raw_response,
        embedding=embedding if isinstance(embedding, list) else None,
        inference_ms=timer.elapsed_ms + gw_ms,
    )

    save_analysis_run(
        db,
        message.id,
        model_name=model_name,
        model_version=model_version,
        analysis_source=message.analysis_source,
        request_payload=request_payload,
        response_payload=raw_response,
        risk_score=risk,
        inference_ms=timer.elapsed_ms + gw_ms,
    )

    sender = db.get(User, message.sender_id) if message.sender_id else None
    auto_training_label(db, message, sender, risk)

    from app.services.user_ml import refresh_user_ml_profile

    if message.sender_id:
        refresh_user_ml_profile(db, message.sender_id)
    if message.impersonated_user_id:
        refresh_user_ml_profile(db, message.impersonated_user_id)

    db.commit()
    db.refresh(features)

    phish = evaluate_phishing_signals(text, metadata)
    if phish["phishing_score"] > risk:
        risk = phish["phishing_score"]
        features.risk_score = risk
        if phish.get("explanation_ru"):
            explanation = phish["explanation_ru"]
        if phish.get("title_ru"):
            title = phish["title_ru"]
        if phish.get("alert_type"):
            alert_type = phish["alert_type"]
        db.add(features)
        db.commit()

    effective_threshold = settings.risk_alert_threshold
    if sender and sender.role == UserRole.scammer:
        effective_threshold = min(effective_threshold, 0.35)
    if phish.get("force_alert"):
        effective_threshold = 0.0

    if risk < effective_threshold:
        return features

    channel_key = str((message.metadata_ or {}).get("channel_name") or message.channel.value)
    if not phish.get("force_alert") and not should_emit_alert(message.sender_id, channel_key):
        return features

    admin_ids = get_admin_user_ids(db)
    if sender and sender.role == UserRole.scammer:
        title = phish.get("title_ru") or "Подозрительное поведение"
        if phish.get("phishing_signals"):
            alert_type = phish.get("alert_type") or "bec_intent"
        else:
            alert_type = "style_anomaly"

    impersonation = bool(metadata.get("impersonates_username") or metadata.get("impersonates"))
    if impersonation or alert_type == "bec_intent":
        if not phish.get("phishing_signals"):
            title = "Возможная компрометация аккаунта"
    if impersonation and alert_type != "bec_intent" and not phish.get("force_alert"):
        alert_type = "bec_intent"
    if phish.get("force_alert") or phish.get("phishing_score", 0) >= 0.45:
        title = phish.get("title_ru") or title or "Возможное мошенничество"

    severity = AlertSeverity.medium
    if risk >= settings.risk_critical_threshold or impersonation:
        severity = AlertSeverity.critical
    elif risk >= settings.risk_high_threshold or phish.get("force_alert"):
        severity = AlertSeverity.high

    alert = Alert(
        severity=severity,
        alert_type=alert_type,
        title_ru=title,
        explanation_ru=explanation,
        related_message_ids=[message.id],
        target_user_ids=admin_ids,
        delivered=False,
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    deliver_alert(db, alert, sender)
    if impersonation and sender and not sender.is_blocked:
        from app.services.telegram_notify import notify_compromise_hint

        notify_compromise_hint(sender.username, sender.display_name, int(risk * 100))
    return features
