start:
	@echo "🚀 Starting Celestia devnet..."
	@docker compose up --build --force-recreate
	@echo "Waiting for services to finish setup"