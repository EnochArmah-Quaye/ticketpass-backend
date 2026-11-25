package com.ticketpass.ticketpass_api.common.error;

import java.lang.reflect.Field;
import java.time.Instant;
import java.util.List;

public record ApiError(String code, String message, Instant timestamp, List<FieldIssue> fields) {
    public record FieldIssue(String field, String message) {}
    public static ApiError of(ErrorCode c, String msg) {
        return new ApiError(c.name(), msg, Instant.now(),null);
    }
}
