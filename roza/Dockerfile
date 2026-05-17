FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY roza ./roza
ENV PYTHONUNBUFFERED=1
EXPOSE 8765
CMD ["python", "-m", "roza", "web", "--host", "0.0.0.0", "--port", "8765"]
