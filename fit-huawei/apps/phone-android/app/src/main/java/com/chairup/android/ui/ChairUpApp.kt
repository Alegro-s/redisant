package com.chairup.android.ui

import androidx.compose.foundation.layout.padding
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.FitnessCenter
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.MonitorWeight
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.chairup.android.ui.navigation.Routes
import com.chairup.android.ui.screens.body.BodyScreen
import com.chairup.android.ui.screens.health.HealthConnectScreen
import com.chairup.android.ui.screens.micro.MicroTimerScreen
import com.chairup.android.ui.screens.coach.WeeklyReportScreen
import com.chairup.android.ui.screens.legal.PrivacyScreen
import com.chairup.android.ui.screens.settings.SettingsScreen
import com.chairup.android.ui.screens.strength.StrengthScreen
import com.chairup.android.ui.screens.strength.StrengthWorkoutScreen
import com.chairup.android.ui.screens.today.TodayScreen

@Composable
fun ChairUpApp() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    val topLevelRoutes = listOf(
        Routes.Today to Icons.Outlined.Home,
        Routes.Body to Icons.Outlined.MonitorWeight,
        Routes.Strength to Icons.Outlined.FitnessCenter,
        Routes.Health to Icons.Outlined.Favorite,
        Routes.Settings to Icons.Outlined.Settings,
    )

    Scaffold(
        bottomBar = {
            NavigationBar {
                topLevelRoutes.forEach { (route, icon) ->
                    val selected = currentDestination?.hierarchy?.any { it.route == route } == true
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(icon, contentDescription = route) },
                        label = {
                            Text(
                                when (route) {
                                    Routes.Today -> "Сегодня"
                                    Routes.Body -> "Тело"
                                    Routes.Strength -> "Сила"
                                    Routes.Health -> "Health"
                                    Routes.Settings -> "Настройки"
                                    else -> route
                                },
                            )
                        },
                    )
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Routes.Today,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(Routes.Today) {
                TodayScreen(
                    onOpenHealth = { navController.navigate(Routes.Health) },
                    onOpenStrength = { navController.navigate(Routes.Strength) },
                    onOpenWeeklyReport = { navController.navigate(Routes.WeeklyReport) },
                    onStartMicro = { slot ->
                        navController.navigate(Routes.microTimer(slot))
                    },
                )
            }
            composable(
                route = Routes.MicroTimer,
                arguments = listOf(navArgument("slotIndex") { type = NavType.IntType }),
            ) { entry ->
                val slot = entry.arguments?.getInt("slotIndex") ?: 0
                MicroTimerScreen(
                    slotIndex = slot,
                    onDone = { navController.popBackStack() },
                    onCancel = { navController.popBackStack() },
                )
            }
            composable(Routes.Body) {
                BodyScreen()
            }
            composable(Routes.Strength) {
                StrengthScreen(
                    onStartTemplate = { id ->
                        navController.navigate(Routes.strengthWorkout(id.key))
                    },
                )
            }
            composable(
                route = Routes.StrengthWorkout,
                arguments = listOf(navArgument("templateId") { type = NavType.StringType }),
            ) { entry ->
                val templateId = entry.arguments?.getString("templateId") ?: "A"
                StrengthWorkoutScreen(
                    onDone = { navController.popBackStack(Routes.Strength, false) },
                    onCancel = { navController.popBackStack() },
                )
            }
            composable(Routes.Health) {
                HealthConnectScreen()
            }
            composable(Routes.Settings) {
                SettingsScreen(
                    onOpenPrivacy = { navController.navigate(Routes.Privacy) },
                    onOpenWeeklyReport = { navController.navigate(Routes.WeeklyReport) },
                )
            }
            composable(Routes.WeeklyReport) {
                WeeklyReportScreen()
            }
            composable(Routes.Privacy) {
                PrivacyScreen()
            }
        }
    }
}
