# ClarifAI: Intelligent Learning Assistant

> An AI-powered learning platform that leverages AI to help students study and prepare better for their examinations. 

---

## 📋 Table of Contents

- [Problem Statement](#problem-statement)
- [Solution Overview](#solution-overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Features](#features)
- [Getting Started](#getting-started)
- [API Documentation](#api-documentation)
- [Development](#development)
- [License](#license)
- [Contributing](#contributing)

---

## 🎯 Problem Statement

Students and learners often struggle with:

1. **Information Overload**: Difficulty organizing and managing large amounts of study material
2. **Retrieval Inefficiency**: Spending excessive time searching through notes to find relevant information
3. **Lack of Personalization**: Generic study tools that don't adapt to individual learning needs
4. **Limited Intelligence**: Simple search functionality without understanding context and relevance
5. **Assessment Challenges**: Creating relevant question papers and mock tests tailored to their study materials

**ClarifAI** solves these problems by providing an intelligent, context-aware learning assistant that:
- Organizes learning materials by topics
- Uses vector embeddings to understand semantic meaning
- Performs intelligent question-answering with Retrieval-Augmented Generation (RAG)
- Falls back to pure LLM capabilities when no relevant materials exist
- Generates assessment papers and practice questions from study materials
- Tracks learning progress through assessments

---

## 💡 Solution Overview

ClarifAI is a **Comprehensive Intelligent Learning Platform** that combines:

1. **Retrieval-Augmented Generation (RAG)**: When users have uploaded learning materials
   - Searches through user's knowledge base using vector similarity
   - Provides answers grounded in user's study materials
   - Ensures accuracy and relevance

2. **Generative AI Fallback**: When no relevant materials exist
   - Leverages Google Gemini Pro's knowledge
   - Provides comprehensive answers without context
   - Seamless transition between modes

3. **Intelligent Assessment Generation**: Creates personalized test papers and assessments
   - Generates questions based on user's study materials and topics
   - Creates mock tests for exam preparation
   - Provides topic-specific practice assessments
   - Helps identify knowledge gaps through assessment results



---

## 🏗️ Architecture

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP/REST API
                             ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                    Backend (Django Framework)                                  │
├────────────────────────────────────────────────────────────────────────────────┤
│ Accounts    │ Topic     │ Knowledge     │ Query    │ Assessment                │
│ ────────    │ ──────    │ ──────────    │ ──────   │ ──────────                │
│ • Register  │ • Submit  │ • Embeddings  │ • QA     │ • Quiz Paper Generation   │
│ • OTP       │ • Notes   │               │ • RAG    │                           │
│ • Auth      │           │               │ • LLM    │                           │
└────┬─────────────┬──────────────┬────────────┬─────────────┬───────────────────┘
     │             │              │            │             │
     ▼             ▼              ▼            ▼             ▼
┌────────┐┌────────┐┌───────────┐┌──────────┐┌────────────────┐
│SQLite  ││JWT     ││Pinecone   ││Google AI ││Assessment Gen  │
│        ││Tokens  ││Vectors    ││Gemini    ││                │
└────────┘└────────┘└───────────┘└──────────┘└────────────────┘
```


### Query Flow Diagram

```
User sends question
        │
        ▼
┌────────────────────┐
│ Verify User Token  │
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ Verify Topic Ownership
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ Generate Embedding │ (Sentence Transformers)
│ for Question       │
└────────────────────┘
        │
        ▼
┌────────────────────┐
│ Search Vector DB   │ (Pinecone)
│ for Similar Notes  │
└────────────────────┘
        │
        ├─── Found Relevant Materials ────┐
        │                                  │
        ▼                                  ▼
    RAG Mode                          LLM-Only Mode
    ─────────                          ─────────────
  Context + Q                          Q Only
        │                                  │
        └──────────────┬───────────────────┘
                       │
                       ▼
            ┌────────────────────┐
            │ Generate Answer    │
            │ (Google Gemini)    │
            └────────────────────┘
                       │
                       ▼
            ┌────────────────────┐
            │ Return Response    │
            │                    │
            └────────────────────┘
```

---

## 🛠️ Tech Stack

### Backend

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Framework** | Django 6.0.2 | Web framework |
| **API** | Django REST Framework 3.15.2 | RESTful API |
| **Authentication** | djangorestframework-simplejwt 5.3.1 | JWT tokens |
| **Embeddings** | sentence-transformers 3.0.1 | Text embeddings |
| **Vector DB** | Pinecone 5.0.0 | Vector search |
| **LLM** | google-generativeai 0.8.3 | Gemini AI |
| **Database** | SQLite 3 | Local storage |
| **Email** | Django SMTP | OTP delivery |
| **CORS** | django-cors-headers 4.6.0 | Cross-origin support |

### Key Libraries

- **Dependencies**: See [requirements.txt](backend/requirements.txt)
- **Python Version**: 3.8+
- **Virtual Environment**: venv

---

## 📁 Repository Structure

```
backend/
├── core/                          # Django project settings
│   ├── settings.py               # Configuration
│   ├── urls.py                   # URL routing
│   ├── wsgi.py                   # WSGI app
│   └── asgi.py                   # ASGI app
│
├── accounts/                      # User authentication & registration
│   ├── models.py                 # EmailOTP model
│   ├── views.py                  # Auth endpoints
│   ├── serializers.py            # Request/response serializers
│   ├── urls.py                   # Auth routes
│   └── migrations/               # Database migrations
│
├── topic/                         # Topic management
│   ├── models.py                 # Topic model
│   ├── views.py                  # Topic endpoints
│   ├── serializers.py            # Serializers
│   ├── urls.py                   # Routes
│   └── migrations/
│
├── knowledge/                     # Knowledge base management
│   ├── models.py                 # KnowledgeNote model
│   ├── views.py                  # CRUD endpoints
│   ├── serializers.py            # Serializers
│   ├── vector_utils.py           # Vector embeddings & search
│   ├── urls.py                   # Routes
│   └── migrations/
│
├── query/                         # Question-answering system
│   ├── models.py                 # Query models
│   ├── views.py                  # QA endpoints
│   ├── serializers.py            # Serializers
│   └── urls.py                   # Routes
│
├── assessment/                    # Assessment module
│   ├── models.py                 # Assessment models
│   ├── views.py                  # Assessment endpoints
│   ├── urls.py                   # Routes
│   └── migrations/
│
├── manage.py                      # Django management
├── db.sqlite3                     # SQLite database
├── requirements.txt               # Dependencies
├── .env                           # Environment variables (gitignored)
├── .env.example                   # Example environment file
│
└── README.md                      # This file
```

---

## ✨ Features

### 🔐 Authentication & Registration
- **Email Verification**: OTP-based email verification
- **Secure Password**: Password validation with strength requirements
- **JWT Authentication**: Token-based authentication
- **Account Management**: Secure logout 

### 📚 Knowledge Management
- **Topic-Based Organization**: Organize notes by topics
- **Rich Text Storage**: Store detailed study materials
- **Vector Embeddings**: Automatic semantic embedding generation
- **User Privacy**: Each user's notes are isolated and secure

### 🔍 Intelligent Q&A
- **Hybrid Approach**: RAG when materials exist, pure LLM otherwise
- **Context Aware**: Grounds answers in user's study materials
- **Fallback Support**: Seamless fallback to LLM when no materials match
- **Transparency**: Response includes `used_rag` flag

### 📊 Assessment & Test Generation
- **Question Paper Generation**: AI-powered generation of questions based on study materials
- **Mock Tests**: Create full-length mock exams for practice
- **Topic-Specific Assessments**: Generate quizzes targeting specific topics
- **Difficulty Levels**: Customize assessment difficulty based on learning progress
- **Progress Tracking**: Monitor learning progress through assessment scores
- **Performance Analytics**: Identify strengths and knowledge gaps

---

## 🚀 Getting Started

### Prerequisites

- Python 3.8 or higher
- pip or conda
- Git

### Installation

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/ClarifAI.git
cd ClarifAI/backend
```

#### 2. Create and Activate Virtual Environment
```bash
python -m venv .venv
source .venv/bin/activate  
```

#### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

#### 4. Configure Environment Variables
Copy `.env.example` to `.env` and fill in your credentials:
```bash
cp .env.example .env 
```

Edit `.env` with your settings:
```env
# Django
SECRET_KEY=your-secret-key
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# Email Configuration (Gmail example)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=your-email@gmail.com

# APIs
GOOGLE_API_KEY=your-gemini-api-key
PINECONE_API_KEY=your-pinecone-key
PINECONE_ENV=your-pinecone-environment
PINECONE_INDEX_NAME=your-index-name
```

#### 5. Run Migrations
```bash
python manage.py makemigrations
python manage.py migrate
```

#### 6. Create Superuser (Optional)
```bash
python manage.py createsuperuser
```

#### 7. Start Development Server
```bash
python manage.py runserver
```

The API will be available at `http://localhost:8000/api/`

---

## 📡 API Documentation

### Authentication Endpoints

#### Register - Send OTP
```http
POST /api/accounts/register/send-otp/
Content-Type: application/json

{
  "email": "user@example.com"
}

Response: 200 OK
{
  "message": "OTP sent to email."
}
```

#### Register - Verify OTP & Create User
```http
POST /api/accounts/register/verify-otp/
Content-Type: application/json

{
  "email": "user@example.com",
  "username": "john_doe",
  "password": "SecurePassword123!",
  "password2": "SecurePassword123!",
  "otp": "123456"
}

Response: 201 Created
{
  "message": "Registration successful.",
  "user": {
    "id": 1,
    "username": "john_doe",
    "email": "user@example.com"
  },
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

#### Login
```http
POST /api/accounts/login/
Content-Type: application/json

{
  "username": "john_doe",
  "password": "SecurePassword123!"
}

Response: 200 OK
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

#### Get Current User
```http
GET /api/accounts/me/
Authorization: Bearer <access_token>

Response: 200 OK
{
  "id": 1,
  "username": "john_doe",
  "email": "user@example.com"
}
```

#### Logout
```http
POST /api/accounts/logout/
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}

Response: 205 Reset Content
```

### Query Endpoint

#### Ask a Question
```http
POST /api/query/
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "question": "What is photosynthesis?",
  "topic": "550e8400-e29b-41d4-a716-446655440000"
}

Response: 200 OK
{
  "answer": "Photosynthesis is the process by which plants...",
  "context": [
    "Notes about photosynthesis from your materials...",
    "More detailed information..."
  ],
  "used_rag": true
}
```

**Note**: `used_rag` will be `false` if no relevant materials were found.

### Complete API Documentation
See [EMAIL_OTP_DOCUMENTATION.md](backend/EMAIL_OTP_DOCUMENTATION.md) for detailed OTP endpoint documentation.

---

## 👨‍💻 Development

### Project Structure Principles

1. **App-Based Architecture**: Each Django app handles a specific domain
2. **Separation of Concerns**: Models, views, and serializers are separate
3. **Clean Code**: Clear naming, proper error handling, type hints where appropriate
4. **Security**: Hashed passwords, token blacklisting, email verification

### Common Development Tasks

#### Create a New App
```bash
python manage.py startapp app_name
```

#### Generate Migrations
```bash
python manage.py makemigrations
```

#### Apply Migrations
```bash
python manage.py migrate
```

#### Run Django Shell
```bash
python manage.py shell
```

#### Create Admin User
```bash
python manage.py createsuperuser
```

#### Access Admin Panel
Navigate to `http://localhost:8000/admin/`

---

| Variable | Purpose | Example |
|----------|---------|---------|
| `SECRET_KEY` | Django secret key | `your-secret-key` |
| `DEBUG` | Debug mode | `True` (development only) |
| `ALLOWED_HOSTS` | Allowed domains | `localhost,127.0.0.1` |
| `EMAIL_HOST` | SMTP server | `smtp.gmail.com` |
| `EMAIL_PORT` | SMTP port | `587` |
| `EMAIL_USE_TLS` | Enable TLS | `True` |
| `EMAIL_HOST_USER` | Email account | `your-email@gmail.com` |
| `EMAIL_HOST_PASSWORD` | App password | `your-app-password` |
| `DEFAULT_FROM_EMAIL` | Sender email | `your-email@gmail.com` |
| `GOOGLE_API_KEY` | Gemini API key | `your-api-key` |
| `PINECONE_API_KEY` | Pinecone API key | `your-pinecone-key` |
| `PINECONE_ENV` | Pinecone environment | `gcp-starter` |
| `PINECONE_INDEX_NAME` | Pinecone index | `knowledge-notes` |

---

## 📚 External Service Setup

### Google Gemini AI

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikeys)
2. Create a new API key
3. Add to `.env` as `GOOGLE_API_KEY`

### Pinecone Vector Database

1. Sign up at [Pinecone](https://www.pinecone.io/)
2. Create a new index with dimension 384 (for sentence-transformers)
3. Get environment and API key
4. Add to `.env`

### Gmail SMTP (Email)

1. Enable 2-Factor Authentication on Google Account
2. Generate App Password at [https://myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
3. Use App Password in `.env`

---

## 🐛 Troubleshooting

### Common Issues

#### OTP Not Sending
- Check email credentials in `.env`
- Verify SMTP port is not blocked (587 for Gmail)
- Check email logs: `python manage.py shell` → `from django.core.mail import send_mail`

#### Vector Search Fails
- Ensure Pinecone API key is valid
- Check network connectivity
- Verify index name matches `PINECONE_INDEX_NAME`

#### Gemini API Errors
- Validate `GOOGLE_API_KEY`
- Check API quotas in Google Cloud Console
- Ensure API is enabled for your project

#### Migration Issues
```bash
python manage.py migrate accounts zero
python manage.py migrate

python manage.py makemigrations --empty accounts --name fix_whatever
```

---

## 📈 Performance Optimization

1. **Database Indexing**: Important fields are indexed
2. **Vector Caching**: Pinecone handles caching
3. **Query Optimization**: Use `.select_related()` and `.prefetch_related()`
4. **Pagination**: Implement pagination for large result sets
5. **Rate Limiting**: Add rate limiting in production

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Make** your changes
4. **Commit** with clear messages (`git commit -m 'Add amazing feature'`)
5. **Push** to the branch (`git push origin feature/amazing-feature`)
6. **Open** a Pull Request

### Code Style

- Follow PEP 8 guidelines
- Use meaningful variable names
- Add docstrings to functions and classes
- Write clean, professional code

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### MIT License Summary

You are free to:
- ✅ Use the software commercially
- ✅ Modify the source code
- ✅ Distribute copies of the software
- ✅ Use it privately

You must:
- ℹ️ Include the original license notice
- ℹ️ Provide a copy of the license

The software is provided "AS IS" without warranty.

### Full License Text

```
MIT License

Copyright (c) 2026 Divyansh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📞 Support & Contact

For questions, issues, or suggestions:

- **GitHub Issues**: [Create an issue](https://github.com/yourusername/ClarifAI/issues)
- **Email**: your-email@example.com
- **Documentation**: See [EMAIL_OTP_DOCUMENTATION.md](backend/EMAIL_OTP_DOCUMENTATION.md)

---

## 🎓 Learning Resources

- [Django Documentation](https://docs.djangoproject.com/)
- [Django REST Framework](https://www.django-rest-framework.org/)
- [Pinecone Documentation](https://docs.pinecone.io/)
- [Sentence Transformers](https://www.sbert.net/)
- [Google Gemini API](https://ai.google.dev/)

---

## 🙏 Acknowledgments

- Built with [Django](https://www.djangoproject.com/)
- Embeddings powered by [Sentence Transformers](https://www.sbert.net/)
- Vector search by [Pinecone](https://www.pinecone.io/)
- AI capabilities from [Google Gemini](https://ai.google.dev/)

---

**Last Updated**: March 9, 2026

**Version**: 1.0.0

---

*ClarifAI - Making Learning Intelligent*
