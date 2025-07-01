package main

import (
	"context"
	"encoding/json"
	"log"
	"math/rand/v2"
	"time"

	"github.com/segmentio/kafka-go"
)

var topic = "bets"
var partition = 3

type BetPaced struct {
	UserID string  `json:"userId"`
	Market string  `json:"market"`
	Stake  float64 `json:"stake"`
	Time   int64   `json:"ts"`
}

func main() {
	w := kafka.Writer{
		Addr:         kafka.TCP("localhost:19092"),
		Topic:        topic,
		Balancer:     &kafka.Hash{},
		RequiredAcks: kafka.RequireAll,
	}

	tick := time.NewTicker(500 * time.Millisecond)
	defer w.Close()

	for t := range tick.C {
		msg := BetPaced{
			UserID: []string{"u123", "u456", "u789"}[rand.IntN(3)],
			Market: "SG",
			Stake:  float64(1+rand.IntN(10)) * 5,
			Time:   t.Unix(),
		}

		payload, _ := json.Marshal(msg)
		if err := w.WriteMessages(context.Background(), kafka.Message{
			Key:   []byte(msg.UserID),
			Value: payload,
			Time:  t,
		}); err != nil {
			log.Printf("write error: %v", err)
		}
	}

}
