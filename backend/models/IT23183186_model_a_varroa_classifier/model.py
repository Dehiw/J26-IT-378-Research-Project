"""MobileNetV2 architecture used by the Varroa image classifier."""

from __future__ import annotations

from torch import nn
from torchvision.models import MobileNet_V2_Weights, mobilenet_v2

from common import CLASS_NAMES


def create_mobilenet_v2_classifier(
    *,
    pretrained: bool = True,
    num_classes: int = len(CLASS_NAMES),
) -> nn.Module:
    """Build MobileNetV2 with an output head for the requested class count.

    Training starts from ImageNet weights by default. Evaluation sets
    ``pretrained=False`` and restores the trained state dictionary.
    """
    weights = MobileNet_V2_Weights.IMAGENET1K_V1 if pretrained else None
    model = mobilenet_v2(weights=weights)
    model.classifier[1] = nn.Linear(model.last_channel, num_classes)
    return model
