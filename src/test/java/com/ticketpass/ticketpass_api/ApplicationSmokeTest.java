package com.ticketpass.ticketpass_api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.assertj.core.api.Assertions.assertThat;

 class ApplicationSmokeTest extends AbstractIntegrationTest {

     @Autowired
     JdbcTemplate jdbc;

     @Test
     void contextLoadsAndAllMigrationsApplied() {
         Integer applied = jdbc.queryForObject(
                 "SELECT count(*) FROM flyway_schema_history WHERE success",
                 Integer.class
         );
         assertThat(applied).isEqualTo(1);
     }
}
