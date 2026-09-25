#pragma once

#include <cstdint>

constexpr uint64_t K_IDLE_TIMEOUT_MS = 5 * 1000;

uint64_t get_monotonic_ms();

int32_t next_timer_ms();

void process_timers();
