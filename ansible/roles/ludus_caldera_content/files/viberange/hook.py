"""VibeRange Caldera content plugin."""

from app.utility.base_world import BaseWorld

name = "VibeRange"
description = "Versioned VibeRange Kubernetes Goat abilities, sources, and adversaries"
address = "/plugin/viberange"
access = BaseWorld.Access.RED


async def enable(services):
    """CALDERA loads this plugin's data files during normal plugin startup."""
    return None
