package com.ticketpass.ticketpass_api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class TicketpassApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(TicketpassApiApplication.class, args);
	}

}
