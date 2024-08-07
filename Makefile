start:
	@echo "🚀 Starting Celestia devnet..."
	@docker compose up --build --force-recreate
	@echo "Waiting for services to finish setup"
# @docker compose logs -f | awk '/Provisioning finished./ {print;exit}'