package com.ticketpass.ticketpass_api.common.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

@Validated
@ConfigurationProperties(prefix = "app")
public record AppProperties(
        @Valid @NotNull Jwt jwt,
        @Valid @NotNull Ticket ticket,
        @Valid @NotNull Order order,
        @NotBlank String baseUrl,
        @NotBlank String frontendUrl ) {
    public record Jwt(@NotBlank String secret, Duration accessTtl, Duration refreshTtl){}

    public record Ticket(@NotBlank String hmacSecret){}

    public record Order(Duration holdDuration, int maxTicketsPerOrder){}
}
