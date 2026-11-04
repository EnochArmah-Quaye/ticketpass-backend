package com.ticketpass.ticketpass_api;

import org.springframework.boot.SpringApplication;

public class TestTicketpassApiApplication {

	public static void main(String[] args) {
		SpringApplication.from(TicketpassApiApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
