package com.ticketpass.ticketpass_api.common.error;

import java.time.Instant;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import lombok.extern.slf4j.Slf4j;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ApiError> api(ApiException e) {
        return ResponseEntity.status(e.code().status()).body(ApiError.of(e.code(),e.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> validation(MethodArgumentNotValidException e) {
        var fields = e.getBindingResult().getFieldErrors().stream()
                .map(f -> new ApiError.FieldIssue(f.getField(), f.getDefaultMessage())).toList();
        return ResponseEntity.badRequest().body(
                new ApiError("VALIDATION_FAILED", "Request validation failed",
                        Instant.now(), fields)
        );
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class,
            MissingRequestHeaderException.class})
    ResponseEntity<ApiError> malformed(Exception e) {
        return ResponseEntity.status(403).body(ApiError.of(ErrorCode.FORBIDDEN,
                "You do not have access to this resource"));
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> unexpected(Exception e) {
        String id = UUID.randomUUID().toString().substring(0,8);
        log.error("Unhandled exception, errorId={}", id, e);
        return ResponseEntity.status(500).body(
                ApiError.of(ErrorCode.INTERNAL_ERROR, "Something went wrong. Reference:" + id)
        );
    }
}
