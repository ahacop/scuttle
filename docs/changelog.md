---
layout: default
title: Changelog
description: What changed in each danky release.
permalink: /changelog/
---

# Changelog

{% capture changelog %}{% include changelog.md %}{% endcapture %}
{{ changelog | markdownify }}
