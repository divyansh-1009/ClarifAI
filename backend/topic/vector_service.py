import os
import uuid
import time
import google.generativeai as genai
from google.api_core.exceptions import ResourceExhausted
from pinecone import Pinecone

genai.configure(api_key=os.getenv('GOOGLE_API_KEY'))

pinecone_client = None
index = None

def _get_pinecone_index():
    """
    Lazily initialize Pinecone client and index.
    """
    global pinecone_client, index
    
    if pinecone_client is None:
        api_key = os.getenv('PINECONE_API_KEY')
        if not api_key or api_key == 'your_pinecone_api_key_here':
            raise ValueError(
                "Pinecone API key not configured. "
                "Please set PINECONE_API_KEY in your .env file"
            )
        
        pinecone_client = Pinecone(api_key=api_key)
        index_name = os.getenv('PINECONE_INDEX_NAME', 'clarif-ai')
        index = pinecone_client.Index(index_name)
    
    return index


def _generate_embedding(text, task_type="retrieval_document"):
    """
    Generate embedding using Google Gemini with retry logic for rate limits.
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
            raise Exception(f"Google API generation error: {str(e)}")

def generate_and_store_embedding(pdf_obj, text):
    """
    Generate embedding for text and store in Pinecone.
    """
    try:
        index = _get_pinecone_index()
        embedding = _generate_embedding(text, task_type="retrieval_document")
        embedding_id = str(uuid.uuid4())
        
        index.upsert(vectors=[
            (embedding_id, embedding, {
                'pdf_id': str(pdf_obj.id),
                'topic_id': str(pdf_obj.topic.id),
                'user_id': str(pdf_obj.topic.user.id),
                'class': pdf_obj.topic.class_name,
                'topic': pdf_obj.topic.topic
            })
        ])
        
        return embedding_id
    except Exception as e:
        raise Exception(f"Failed to generate and store embedding: {str(e)}")


def retrieve_embeddings(query_text, top_k=5):
    """
    Retrieve similar embeddings from Pinecone.
    """
    try:
        index = _get_pinecone_index()
        query_embedding = _generate_embedding(query_text, task_type="retrieval_query")
        results = index.query(vector=query_embedding, top_k=top_k, include_metadata=True)
        return results
    except Exception as e:
        raise Exception(f"Failed to retrieve embeddings: {str(e)}")
