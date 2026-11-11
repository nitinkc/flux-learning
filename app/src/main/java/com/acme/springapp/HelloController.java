package com.acme.springapp;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HelloController {

    @Value("${app.message:hello from spring-app}")
    private String message;

    @GetMapping("/api/hello")
    public Map<String, String> hello() {
        return Map.of("message", message);
    }
}
