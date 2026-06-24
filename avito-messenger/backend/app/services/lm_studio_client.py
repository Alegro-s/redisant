from app.services.inference_gateway import (
    EXPECTED_MS,
    GatewayChatResult,
    GatewayEnrichment,
    GatewayStatus,
    enrich_with_gateway,
    gateway_chat,
    gateway_configured,
    gateway_status,
    gray_zone_judge,
    list_gateway_models,
)

LmStudioStatus = GatewayStatus
LmStudioEnrichment = GatewayEnrichment
LmStudioChatResult = GatewayChatResult

lm_studio_configured = gateway_configured
lm_studio_status = gateway_status
list_lm_models = list_gateway_models
lm_studio_chat = gateway_chat
enrich_with_lm_studio = enrich_with_gateway
