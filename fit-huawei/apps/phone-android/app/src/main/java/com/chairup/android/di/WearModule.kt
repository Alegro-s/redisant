package com.chairup.android.di

import com.chairup.android.integration.wear.WearBridge
import com.chairup.android.integration.wear.WearEngineBridge
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class WearModule {
    @Binds
    @Singleton
    abstract fun bindWearBridge(impl: WearEngineBridge): WearBridge
}
