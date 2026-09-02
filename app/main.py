import os

import psycopg
from fastapi import FastAPI

app = FastAPI(title="Homelab App")


@app.get("/")
def root():
    return {
        "application": "homelab-app",
        "status": "running"
    }


@app.get("/health")
def health():
    database_url = os.getenv("DATABASE_URL")

    try:
        with psycopg.connect(database_url) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()

        return {
            "status": "healthy",
            "database": "connected"
        }

    except Exception as error:
        return {
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(error)
        }
