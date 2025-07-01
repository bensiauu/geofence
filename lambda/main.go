package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/location"
	loctypes "github.com/aws/aws-sdk-go-v2/service/location/types"
)

var collections = os.Getenv("COLLECTION_NAME")
var locClient *location.Client

type request struct {
	DeviceID string  `json:"deviceId"`
	Lat      float64 `json:"lat"`
	Lon      float64 `json:"lon"`
}

type response struct {
	Status string `json:"status"`
}

func handler(ctx context.Context, evt events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	raw := evt.Body

	log.Printf("RAW BODY: %q", raw)
	if evt.IsBase64Encoded {
		log.Printf("request is base64 encoded: %q", raw)
		decoded, err := base64.StdEncoding.DecodeString(raw)
		if err != nil {
			log.Printf("base64 decode error: %v", err)
			return events.APIGatewayV2HTTPResponse{StatusCode: 400}, nil
		}
		raw = string(decoded)
	}
	var req request

	if err := json.Unmarshal([]byte(raw), &req); err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 400}, err
	}

	out, err := locClient.BatchEvaluateGeofences(ctx, &location.BatchEvaluateGeofencesInput{
		CollectionName: aws.String(collections),
		DevicePositionUpdates: []loctypes.DevicePositionUpdate{{
			DeviceId:   aws.String(req.DeviceID),
			SampleTime: aws.Time(time.Now()),
			Position:   []float64{req.Lon, req.Lat}, // [lon, lat] per GeoJSON order
		}},
	})
	if err != nil {
		log.Printf("geoforce eval error %v", err)
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: err.Error()}, err
	}

	allowed := len(out.Errors) == 0
	status := map[bool]string{true: "ALLOWED", false: "BLOCKED"}[allowed]

	body, _ := json.Marshal(response{Status: status})
	return events.APIGatewayV2HTTPResponse{
		StatusCode: 200,
		Body:       string(body),
		Headers:    map[string]string{"Content-Type": "application/json"},
	}, nil
}
func main() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	locClient = location.NewFromConfig(cfg)
	lambda.Start(handler)
}
