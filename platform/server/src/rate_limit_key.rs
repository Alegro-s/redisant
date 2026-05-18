//! Rate-limit key: real client IP from nginx (`X-Forwarded-For` / `X-Real-IP`) when peer is local.

use actix_governor::{KeyExtractor, SimpleKeyExtractionError};
use actix_web::dev::ServiceRequest;
use std::net::IpAddr;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ForwardedIpKeyExtractor;

fn parse_ip_header(value: &str) -> Option<IpAddr> {
  value
    .split(',')
    .map(str::trim)
    .find(|s| !s.is_empty())
    .and_then(|s| s.parse().ok())
}

impl KeyExtractor for ForwardedIpKeyExtractor {
  type Key = IpAddr;
  type KeyExtractionError = SimpleKeyExtractionError<&'static str>;

  fn extract(&self, req: &ServiceRequest) -> Result<Self::Key, Self::KeyExtractionError> {
    let peer_ip = req.peer_addr().map(|s| s.ip()).ok_or_else(|| {
      SimpleKeyExtractionError::new("Could not extract peer IP address from request")
    })?;

    let trust_forwarded = peer_ip.is_loopback()
        || matches!(peer_ip, IpAddr::V4(v4) if v4.is_private());
    if trust_forwarded {
      if let Some(xff) = req
        .headers()
        .get("x-forwarded-for")
        .and_then(|h| h.to_str().ok())
      {
        if let Some(ip) = parse_ip_header(xff) {
          return Ok(ip);
        }
      }
      if let Some(xri) = req.headers().get("x-real-ip").and_then(|h| h.to_str().ok()) {
        if let Some(ip) = parse_ip_header(xri) {
          return Ok(ip);
        }
      }
    }

    Ok(peer_ip)
  }
}
