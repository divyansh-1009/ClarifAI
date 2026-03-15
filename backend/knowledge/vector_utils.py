import os
import time
import google.generativeai as genai
from google.api_core.exceptions import ResourceExhausted
from pinecone import Pinecone

genai.configure(api_key=os.getenv('GOOGLE_API_KEY'))

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "knowledge-notes")

try:
    if PINECONE_API_KEY:
        pc = Pinecone(api_key=PINECONE_API_KEY)
    else:
        pc = None
except Exception:
    pc = None


def get_or_create_index():
    if not pc:
        return None
    if INDEX_NAME not in pc.list_indexes().names():
        pc.create_index(
            name=INDEX_NAME,
            dimension=768,      # Google text-embedding-004 uses 768 dimensions
            metric="cosine"
        )
    return pc.Index(INDEX_NAME)


def generate_embedding(text, task_type="retrieval_document"):
    """
    Generate embedding using Google Gemini with retry/exponential backoff for rate limits.
    """
    retries = 3
    delay = 5
    for attempt in range(retries):
        try:
            result = genai.embed_content(
                model="models/text-embedding-004",
                content=text,
                task_type=task_type
            )
            return result['embedding']
        except ResourceExhausted:
            if attempt < retries - 1:
                time.sleep(delay)
                delay *= 2  # exponential backoff
            else:
                raise Exception("Rate limit exhausted (429) for Gemini API after retries.")
        except Exception as e:
            raise Exception(f"Google API embedding error: {str(e)}")


def upsert_note_vector(note_id, embedding, metadata):
    index = get_or_create_index()
    if index:
        index.upsert([(str(note_id), embedding, metadata)])


def query_similar_notes(embedding, top_k=5, filter_dict=None):
    index = get_or_create_index()
    if not index:
        return []
    query = index.query(vector=embedding, top_k=top_k, include_metadata=True, filter=filter_dict)
    return query["matches"]
