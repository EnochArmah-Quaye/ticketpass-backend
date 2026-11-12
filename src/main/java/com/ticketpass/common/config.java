package com.ticketpass.common.config;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;
import java.time.Duration;

@Validated
@CondigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Ticket ticket, Order order,
                            @NotBlank String baseUrl, @NotBlank String frontendUrl) {
    public record Jwt(@NotBlank String secret, Duration accessTtl, Duration refreshTtl)
    {}
    public record Ticket(@NotBlank String hmacSecret) {}
    public record Order(Duration holdDuration, int maxTicketPerOrder) {}
}