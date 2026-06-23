package com.chairup.android.integration.health

sealed class HealthAuthState {
    data object Unknown : HealthAuthState()
    data object NotConfigured : HealthAuthState()
    data object NotAuthorized : HealthAuthState()
    data class Authorized(val scopes: List<String> = emptyList()) : HealthAuthState()
    data class Error(val message: String) : HealthAuthState()
}
