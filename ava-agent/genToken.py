# generate_token.py
from livekit import api
from dotenv import load_dotenv
import os

load_dotenv(".env.local")

token = api.AccessToken(
    os.getenv("APIvfFdsU72jrb5"),
    os.getenv("FQXcyLBeefmHNQie84Su2IXo5kOM88QDr017benbRJuB"),
) \
    .with_identity("godot-user") \
    .with_name("godot-user") \
    .with_grants(api.VideoGrants(room_join=True, room="console-4f066687")) \
    .with_room_config(
        api.RoomConfiguration(
            agents=[api.RoomAgentDispatch(agent_name="ava-agent-test")]
        )
    ) \
    .to_jwt()

print("URL:", os.getenv("LIVEKIT_URL"))
print("Token:", token)