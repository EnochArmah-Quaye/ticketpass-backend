package com.ticketpass.ticketpass_api.service;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ticketpass.ticketpass_api.common.config.AppProperties;
import com.ticketpass.ticketpass_api.common.error.ApiException;
import com.ticketpass.ticketpass_api.common.error.ErrorCode;
import com.ticketpass.ticketpass_api.common.security.Hashing;
import com.ticketpass.ticketpass_api.entity.RefreshToken;
import com.ticketpass.ticketpass_api.repository.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private final RefreshTokenRepository repo;
    private final AppProperties props;
    private final SecureRandom random = new SecureRandom();

    public record Issued(String rawToken, RefreshToken entity) {}

    @Transactional
    public String startFamily(UUID userId) { return create(userId, UUID.randomUUID()); }

    private String create(UUID userId, UUID family) {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        RefreshToken t = new RefreshToken();
        t.setUserId(userId); t.setFamilyId(familyId); t.setTokenHash(Hashing.sha256Hex(raw));
        t.setExpiresAt(Instant.now().plus(props.jwt().refreshTtl()));
        repo.save(t);
        return raw;
    }

    /** Returns userId and the NEW raw token. Throws if invalid, expired, revoked or reused. */
    @Transactional(noRollbackFor = ApiException.class)
    public Rotated rotate(String rawToken) {
        RefreshToken old = repo.findByTokenHash(Hashing.sha256Hex(rawToken))
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_REFRESH_TOKEN,
                        "Invalid refresh token"));
        Instant now = Instant.now();
        if (old.getRevokedAt() != null) {
            repo.revokeFamily(old.getFamilyId(), now); // reuse detected: kill the whole family
             throw new ApiException(ErrorCode.INVALID_REFRESH_TOKEN, "Invalid refresh token");
        }
        if (old.getExpiresAt().isBefore(now))
            throw new ApiException(ErrorCode.INVALID_REFRESH_TOKEN, "Invalid refresh token");
        old.setRevokedAt(now);
        String next = create(old.getUserId(), old.getFamilyId());
        return new Rotated(old.getUserId(), next);
    }

    public record Rotated(UUID userId, String rawToken) {}

}
