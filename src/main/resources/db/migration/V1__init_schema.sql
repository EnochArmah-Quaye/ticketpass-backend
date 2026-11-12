--  Baseline schema. Tables are created in dependency order:
-- every foreign key points to a table created ABOVE it.

-- 1. users (depends on: nothing (created first))
CREATE TABLE users (
   id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   email            VARCHAR(255) NOT NULL,
   password_hash    VARCHAR(100) NOT NULL,
   full_name        VARCHAR(120) NOT NULL,
   role             VARCHAR(20) NOT NULL,
   created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
   updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
   CONSTRAINT uq_users_email UNIQUE (email),
   CONSTRAINT ck_users_email_lower CHECK (email = lower(email)),
   CONSTRAINT ck_users_role CHECK (role IN ('BUYER','ORGANIZER','STAFF','ADMIN'))
);

-- 2. refresh_tokens (depends on: users)
CREATE TABLE refresh_tokens (
   id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   user_id                   UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
   family_id                 UUID NOT NULL,
   token_hash                CHAR(64) NOT NULL,
   expires_at                TIMESTAMPTZ NOT NULL,
   revoked_at                TIMESTAMPTZ,
   created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
   CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash)
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_family ON refresh_tokens (family_id);

-- 3. events (depends on: users)
CREATE TABLE events (
   id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   organizer_id      UUID NOT NULL REFERENCES users (id),
   title             VARCHAR(200) NOT NULL,
   description       TEXT,
   venue             VARCHAR(200) NOT NULL,
   city              VARCHAR(100) NOT NULL,
   starts_at         TIMESTAMPTZ NOT NULL,
   ends_at           TIMESTAMPTZ NOT NULL,
   status            VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
   slug              VARCHAR(220) NOT NULL,
   created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
   updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
   CONSTRAINT uq_events_slug UNIQUE (slug),
   CONSTRAINT ck_events_status CHECK (status IN
   ('DRAFT','PUBLISHED','CANCELLED','ENDED')),
   CONSTRAINT ck_events_time CHECK (ends_at > starts_at)
);
CREATE INDEX idx_events_organizer ON events (organizer_id);
CREATE INDEX idx_events_public ON events (status, starts_at);
CREATE INDEX idx_events_city ON events (city);

-- 4. ticket_types (depends on: events)
CREATE TABLE ticket_types (
   id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   event_id                UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
   name                    VARCHAR(80) NOT NULL,
   price_pesewas           BIGINT NOT NULL,
   quantity_total          INT NOT NULL,
   quantity_sold           INT NOT NULL DEFAULT 0,
   sales_start             TIMESTAMPTZ NOT NULL,
   sales_end               TIMESTAMPTZ NOT NULL,
   version                 BIGINT NOT NULL DEFAULT 0,
   created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
   CONSTRAINT uq_ticket_types_event_name UNIQUE (event_id, name),
   CONSTRAINT ck_tt_price CHECK (price_pesewas >= 0),
   CONSTRAINT ck_tt_total CHECK (quantity_total >= 0),
   CONSTRAINT ck_tt_sold_nonneg CHECK (quantity_sold >= 0),
   CONSTRAINT ck_tt_sold_le_total CHECK (quantity_sold <= quantity_total),
   CONSTRAINT ck_tt_window CHECK (sales_end > sales_start)
);
CREATE INDEX idx_ticket_types_event ON ticket_types (event_id);

-- 5. orders (depends on: users, events)
CREATE TABLE orders (
   id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   buyer_id          UUID NOT NULL REFERENCES users (id),
   event_id          UUID NOT NULL REFERENCES events (id),
   status            VARCHAR(20) NOT NULL DEFAULT 'PENDING',
   total_pesewas     BIGINT NOT NULL,
   expires_at        TIMESTAMPTZ NOT NULL,
   idempotency_key   VARCHAR(100) NOT NULL,
   paystack_reference VARCHAR(100) NOT NULL,
   payment_url       TEXT,
   created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
   updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
   CONSTRAINT uq_orders_buyer_idem UNIQUE (buyer_id, idempotency_key),
   CONSTRAINT uq_orders_paystack_ref UNIQUE (paystack_reference),
   CONSTRAINT ck_orders_status CHECK (status IN ('PENDING','PAID','EXPIRED','FAILED')),
   CONSTRAINT ck_orders_total CHECK (total_pesewas >= 0)
);
CREATE INDEX idx_orders_status_expiry ON orders (status, expires_at);
CREATE INDEX idx_orders_buyer ON orders (buyer_id, created_at DESC);

-- 6. orders_items (depends on: orders, ticket_types)
CREATE TABLE orders_items (
   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   order_id UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
   ticket_type_id UUID NOT NULL REFERENCES ticket_types (id),
   quantity INT NOT NULL,
   unit_price_pesewas BIGINT NOT NULL,
   CONSTRAINT ck_oi_quantity CHECK (quantity > 0),
   CONSTRAINT ck_oi_price CHECK (unit_price_pesewas >= 0),
   CONSTRAINT uq_oi_order_type UNIQUE (order_id, ticket_type_id)
);
CREATE INDEX idx_order_items_order ON order_items (order_id);

-- 7. payments (depends on: orders)
CREATE TABLE payments (
   id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   order_id            UUID NOT NULL REFERENCES orders (id),
   provider_reference  VARCHAR(100) NOT NULL,
   amount_pesewas      BIGINT NOT NULL,
   status              VARCHAR(20) NOT NULL,
   raw_payload         JSONB,
   paid_at             TIMESTAMPTZ,
   created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
   CONSTRAINT uq_payments_order UNIQUE (order_id),
   CONSTRAINT uq_payments_provider_ref UNIQUE (provider_reference),
   CONSTRAINT ck_payments_status CHECK (status IN
   ('SUCCESS','FAILED','NEEDS_REFUND','NEEDS_REVIEW'))
);

-- 8. tickets (depends on: order_items, events)
CREATE TABLE tickets (
   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   order_item_id UUID NOT NULL REFERENCES order_items (id),
   event_id UUID NOT NULL REFERENCES events (id),
   holder_name VARCHAR(120) NOT NULL,
   code VARCHAR(64) NOT NULL,
   status VARCHAR(10) NOT NULL DEFAULT 'VALID',
   issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
   CONSTRAINT uq_tickets_code UNIQUE (code),
   CONSTRAINT ck_tickets_status CHECK (status IN ('VALID','USED','VOID'))
);
CREATE INDEX idx_tickets_event ON tickets (event_id, status);
CREATE INDEX idx_tickets_order_item ON tickets (order_item_id);

-- 9. check_ins (depends on: tickets, events, users)
CREATE TABLE check_ins (
   id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   ticket_id            UUID REFERENCES tickets (id), -- null when the QR was forged/unknown
   event_id             UUID NOT NULL REFERENCES events (id),
   scanned_by           UUID NOT NULL REFERENCES users (id),
   scanned_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    result              VARCHAR(15) NOT NULL,
   CONSTRAINT ck_check_ins_result CHECK (result IN
    ('SUCCESS','DUPLICATE','INVALID','WRONG_EVENT'))
);
CREATE UNIQUE INDEX uq_check_ins_one_success ON check_ins (ticket_id) WHERE result = 'SUCCESS';
CREATE INDEX idx_check_ins_event ON check_ins (event_id, scanned_at);

-- 10. event_staff (depends on: events, users)
CREATE TABLE event_staff (
   event_id               UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
   user_id                UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
   invited_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
   PRIMARY KEY (event_id, user_id)
);

-- 11. notification_outbox (depends on: nothing (standalone))
CREATE TABLE notification_outbox (
   id                             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   type                           VARCHAR(40) NOT NULL,
   recipient                      VARCHAR(255) NOT NULL,
   payload                        JSONB NOT NULL,
   status                         VARCHAR(10) NOT NULL DEFAULT 'PENDING',
   attempts                       INT NOT NULL DEFAULT 0,
   next_attempt_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
   last_error                     TEXT,
   created_at                     TIMESTAMPTZ NOT NULL DEFAULT now(),
   sent_at                        TIMESTAMPTZ,
   CONSTRAINT ck_outbox_status CHECK (status IN ('PENDING','SENT','FAILED'))
);
CREATE INDEX idx_outbox_due ON notification_outbox (status, next_attempt_at);