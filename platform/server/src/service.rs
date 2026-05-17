#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PoService {
    Auth,
    Waypoint,
    Lynx,
}

impl PoService {
    pub fn from_env() -> Self {
        match std::env::var("PO_SERVICE")
            .unwrap_or_else(|_| "waypoint".into())
            .to_lowercase()
            .as_str()
        {
            "auth" => Self::Auth,
            "lynx" => Self::Lynx,
            _ => Self::Waypoint,
        }
    }

    pub fn default_bind_address(&self) -> &'static str {
        match self {
            Self::Auth => "127.0.0.1:8090",
            Self::Waypoint => "127.0.0.1:8080",
            Self::Lynx => "127.0.0.1:8082",
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            Self::Auth => "auth-api",
            Self::Waypoint => "waypoint-api",
            Self::Lynx => "lynx-api",
        }
    }
}
