output "invoke_url" {
  description = "Base URL for POST /check"
  value       = aws_apigatewayv2_api.geo_api.api_endpoint
}

output "collection_arn" {
  description = "ARN of the Location Service geofence collection"
  value       = aws_location_geofence_collection.bet_regions.collection_arn
}
