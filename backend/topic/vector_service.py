import os
import uuid
from sentence_transformers import SentenceTransformer
from pinecone import Pinecone

model = SentenceTransformer('all-MiniLM-L6-v2')

pinecone_client = None
index = None

def _get_pinecone_index():
    """
    Lazily initialize Pinecone client and index.
    Allows server to start even if Pinecone credentials are not configured.
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


def generate_and_store_embedding(pdf_obj, text):
    """
    Generate embedding for text and store in Pinecone.
    Returns the embedding_id used for storage.
    """
    try:
        index = _get_pinecone_index()
        embedding = model.encode(text).tolist()
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
        query_embedding = model.encode(query_text).tolist()
        results = index.query(vector=query_embedding, top_k=top_k, include_metadata=True)
        return results
    except Exception as e:
        raise Exception(f"Failed to retrieve embeddings: {str(e)}")
