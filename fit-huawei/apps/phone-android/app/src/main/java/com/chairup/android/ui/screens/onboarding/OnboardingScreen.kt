package com.chairup.android.ui.screens.onboarding

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.chairup.android.ui.theme.ChairAccent
import kotlinx.coroutines.launch

private data class OnboardingPage(
    val title: String,
    val body: String,
    val action: String,
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(
    onOpenHealth: () -> Unit,
    onDone: () -> Unit,
) {
    val pages = listOf(
        OnboardingPage(
            title = "HUAWEI Health",
            body = "ChairUp читает шаги, сон и пульс из Health — как зеркало, без лишней возни.",
            action = "Далее",
        ),
        OnboardingPage(
            title = "Батарея EMUI",
            body = "Разрешите автозапуск и отключите оптимизацию батареи — иначе синк ночью может отвалиться.",
            action = "Далее",
        ),
        OnboardingPage(
            title = "Часы HarmonyOS",
            body = "Установите ChairUp на часы (DevEco). В Wave 2 — микро-сессии «2 минуты» с вибрацией.",
            action = "Начать",
        ),
    )
    val pager = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        HorizontalPager(
            state = pager,
            modifier = Modifier.weight(1f),
        ) { index ->
            val page = pages[index]
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
            ) {
                Text(page.title, style = MaterialTheme.typography.headlineMedium)
                Spacer(Modifier.height(16.dp))
                Text(
                    page.body,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Start,
                )
                if (index == 0) {
                    Spacer(Modifier.height(20.dp))
                    Button(
                        onClick = onOpenHealth,
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
                    ) {
                        Text("Подключить Health сейчас")
                    }
                }
            }
        }

        Button(
            onClick = {
                if (pager.currentPage < pages.lastIndex) {
                    scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
                } else {
                    onDone()
                }
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
        ) {
            Text(pages[pager.currentPage].action)
        }
    }
}
