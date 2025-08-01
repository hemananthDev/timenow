# app/app.py
from flask import Flask, jsonify
from datetime import datetime

app = Flask(__name__)

@app.route('/time')
def current_time():
    now = datetime.now()
    return jsonify({"current_time": now.strftime('%Y-%m-%d %H:%M:%S')})

@app.route('/')
def home():
    return "Welcome! Try /time for the current time."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
