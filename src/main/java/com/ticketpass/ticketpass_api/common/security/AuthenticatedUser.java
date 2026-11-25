package com.ticketpass.ticketpass_api.common.security;

import java.util.UUID;
import com.ticketpass.ticketpass_api.enums.Role;

public record AuthenticatedUser(UUID id, Role role) {
}
