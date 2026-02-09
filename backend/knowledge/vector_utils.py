from sentence_transformers import SentenceTransformer
import pinecone
import os

MODEL_NAME = "all-MiniLM-L6-v2"
model = SentenceTransformer(MODEL_NAME)

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
PINECONE_ENV = os.getenv("PINECONE_ENV", "gcp-starter")
INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "knowledge-notes")

try:
    if PINECONE_API_KEY:
        pc = pinecone.Pinecone(api_key=PINECONE_API_KEY)
    else:
        pc = None
except Exception as e:
    pc = None

def get_or_create_index():
    if not pc:
        return None
    if INDEX_NAME not in pc.list_indexes().names():
        pc.create_index(
            name=INDEX_NAME, 
            dimension=384, 
            metric="cosine"
        )
    return pc.Index(INDEX_NAME)

def generate_embedding(text):
    embedding = model.encode(text)
    return embedding.tolist()

def upsert_note_vector(note_id, embedding, metadata):
    index = get_or_create_index()
    index.upsert([(str(note_id), embedding, metadata)])

def query_similar_notes(embedding, top_k=5, filter_dict=None):
    index = get_or_create_index()
    query = index.query(vector=embedding, top_k=top_k, include_metadata=True, filter=filter_dict)
    return query["matches"]
