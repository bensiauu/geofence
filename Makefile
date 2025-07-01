ZIP = lambda/geo.zip
LAMBDA_DIR = lambda
TF_DIR = terraform

.PHONY: build zip deploy destroy invoke

build:
	cd $(LAMBDA_DIR) && ./build.sh

zip: build  ## alias

deploy: zip
	cd $(TF_DIR) && terraform init -upgrade && terraform apply -auto-approve

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

invoke:     ## quick test with sample coords (NJ)
	curl -X POST "$$(cd $(TF_DIR) && terraform output -raw invoke_url)/check" \
	     -d '{"deviceId":"u123","lat":40.226,"lon":-74.012}' | jq
