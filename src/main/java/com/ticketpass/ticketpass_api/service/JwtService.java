package com.ticketpass.ticketpass_api.service;

import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;
import com.ticketpass.ticketpass_api.common.config.AppProperties;
import com.ticketpass.ticketpass_api.enums.Role;
import com.ticketpass.ticketpass_api.common.security.AuthenticatedUser;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;

@Service
public class JwtService {

    private final SecretKey key;
    private final Duration accessTtl;

    public JwtService(AppProperties props) {
        byte[] bytes = Decoders.BASE64.decode(props.jwt().secret());
        if (bytes.length < 32)
            throw new IllegalStateException("JWT_SECRET must decode to at least 32 bytes");
        this.key = Keys.hmacShaKeyFor(bytes);
        this.accessTtl = props.jwt().accessTtl();
    }

    public String issue(UUID userId, Role role) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .claim("role", role.name())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTtl)))
                .signWith(key)
                .compact();
    }

    public Optional<AuthenticatedUser> parse(String token) {
        try { Claims c = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
            return Optional.of(new AuthenticatedUser(UUID.fromString(c.getSubject()),
                    Role.valueOf(c.get("role", String.class))));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty(); // never reveal WHY a token failed
        }
    }

    public long accessTtlSeconds() {
        return accessTtl.toSeconds();
    }
}
