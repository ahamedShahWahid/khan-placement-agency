"""Embedding providers and profile canonicalization.

Public surface: ``EmbeddingProvider`` Protocol with two implementations
(currently only Gemini), an ``EmbeddingTask`` enum that distinguishes document
vs query encoding, and the ``canonicalize_profile`` helper that produces the
deterministic text + sha256 used as the idempotency key on
``applicant_embeddings.canonicalized_text_hash``.
"""
from kpa.integrations.embeddings.base import (
    EmbeddingProvider,
    EmbeddingProviderError,
    EmbeddingResult,
    EmbeddingTask,
    TransientEmbeddingError,
)
from kpa.integrations.embeddings.canonicalize import canonicalize_profile
from kpa.integrations.embeddings.gemini import GeminiEmbeddingProvider

__all__ = [
    "EmbeddingProvider",
    "EmbeddingProviderError",
    "EmbeddingResult",
    "EmbeddingTask",
    "TransientEmbeddingError",
    "canonicalize_profile",
    "GeminiEmbeddingProvider",
]
