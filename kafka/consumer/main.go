package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	kafka "github.com/segmentio/kafka-go"
)

type BetPlaced struct {
	UserID string  `json:"userId"`
	Stake  float64 `json:"stake"`
	Time   int64   `json:"ts"`
}

func main() {
	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers:  []string{"localhost:19092"},
		Topic:    "bets",
		GroupID:  "stake-aggregator",
		MaxBytes: 1e6,
	})

	type window struct {
		Sum       float64
		ExpiresAt time.Time
	}
	windows := map[string]window{}

	for {
		m, err := r.ReadMessage(context.Background())
		if err != nil {
			log.Fatalf("read error: %v", "err")
		}

		log.Printf("message received: %q", m.Value)

		var bet BetPlaced
		if err := json.Unmarshal(m.Value, &bet); err != nil {
			log.Fatalf("Error unmarshalling bet: %v", err)
			continue
		}

		now := time.Now()
		for k, w := range windows {
			if now.After(w.ExpiresAt) {
				delete(windows, k)
			}
		}

		win := windows[bet.UserID]
		win.Sum += bet.Stake
		win.ExpiresAt = time.Unix(bet.Time, 0).Add(time.Minute)
		windows[bet.UserID] = win

		fmt.Printf("User %s, running sum: %.2f, window expires at: %s", bet.UserID, win.Sum, win.ExpiresAt)
	}

}
