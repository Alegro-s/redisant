package com.chairup.android.di

import com.chairup.android.integration.health.DefaultHealthGateway
import com.chairup.android.integration.health.HealthGateway
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class HealthModule {
    @Binds
    @Singleton
    abstract fun bindHealthGateway(impl: DefaultHealthGateway): HealthGateway
}
