package com.chairup.android.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.chairup.android.ui.navigation.Routes
import com.chairup.android.ui.screens.onboarding.OnboardingScreen

@Composable
fun ChairUpRoot(
    mainViewModel: MainViewModel = hiltViewModel(),
) {
    val onboardingDone by mainViewModel.onboardingComplete.collectAsStateWithLifecycle()
    val nav = rememberNavController()

    if (!onboardingDone) {
        NavHost(navController = nav, startDestination = Routes.Onboarding) {
            composable(Routes.Onboarding) {
                OnboardingScreen(
                    onOpenHealth = { nav.navigate(Routes.Health) },
                    onDone = { mainViewModel.completeOnboarding() },
                )
            }
            composable(Routes.Health) {
                com.chairup.android.ui.screens.health.HealthConnectScreen()
            }
        }
    } else {
        ChairUpApp()
    }
}
