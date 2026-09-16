#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

CATEGORY_LABELS = {"movies": "Movies", "tv": "TV", "anime": "Anime"}
DEFAULT_CATEGORY = "other"


def load_config(path):
    with open(path, "r") as f:
        return json.load(f)


def fetch_history(instance, since):
    url = instance["url"].rstrip("/") + "/api/v3/history/since"
    query = (
        "date=" + since.strftime("%Y-%m-%dT%H:%M:%SZ")
        + "&includeSeries=true&includeEpisode=true&includeMovie=true"
    )
    req = urllib.request.Request(
        url + "?" + query,
        headers={"X-Api-Key": instance["api_key"], "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=8) as resp:
        return json.loads(resp.read().decode("utf-8"))


def ago(dt, now):
    delta = now - dt
    secs = delta.total_seconds()
    if secs < 90:
        return "just now"
    mins = int(secs / 60)
    if mins < 60:
        return f"{mins}m ago"
    hours = int(mins / 60)
    if hours < 24:
        return f"{hours}h ago"
    days = int(hours / 24)
    if days == 1:
        return "yesterday"
    return f"{days}d ago"


def parse_record(record, instance, now):
    if record.get("eventType") != "downloadFolderImported":
        return None
    try:
        date = datetime.strptime(record["date"], "%Y-%m-%dT%H:%M:%S.%fZ").replace(tzinfo=timezone.utc)
    except (KeyError, ValueError):
        try:
            date = datetime.strptime(record["date"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        except (KeyError, ValueError):
            return None

    quality = (record.get("quality") or {}).get("quality", {}).get("name", "")

    series = record.get("series")
    episode = record.get("episode")
    movie = record.get("movie")

    season_episode = None
    if series:
        title = series.get("title", record.get("sourceTitle", "Unknown"))
        if episode:
            season = episode.get("seasonNumber", 0)
            ep = episode.get("episodeNumber", 0)
            ep_title = episode.get("title", "")
            subtitle = f"S{season:02d}E{ep:02d}" + (f" · {ep_title}" if ep_title else "")
            season_episode = (season, ep)
        else:
            subtitle = ""
    elif movie:
        year = movie.get("year", "")
        title = movie.get("title", record.get("sourceTitle", "Unknown"))
        subtitle = str(year) if year else ""
    else:
        title = record.get("sourceTitle", "Unknown")
        subtitle = ""

    return {
        "title": title,
        "subtitle": subtitle,
        "quality": quality,
        "category": instance.get("category") or DEFAULT_CATEGORY,
        "instance": instance["name"],
        "date": date.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "ago": ago(date, now),
        "count": 1,
        "_sort": date.timestamp(),
        "_season_episode": season_episode,
    }


def group_items(items):
    groups = {}
    order = []
    for item in items:
        key = (item["category"], item["instance"], item["title"])
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append(item)

    merged = []
    for key in order:
        group = groups[key]
        if len(group) == 1:
            merged.append(group[0])
            continue

        group.sort(key=lambda x: x["_sort"], reverse=True)
        newest = dict(group[0])
        newest["count"] = len(group)

        eps = [g["_season_episode"] for g in group if g["_season_episode"]]
        if len(eps) == len(group):
            seasons = sorted(set(s for s, _ in eps))
            if len(seasons) == 1:
                nums = sorted(e for _, e in eps)
                span = f"S{seasons[0]:02d}E{nums[0]:02d}" + (
                    f"–{nums[-1]:02d}" if nums[0] != nums[-1] else ""
                )
                newest["subtitle"] = f"{span} · {len(group)} episodes"
            else:
                newest["subtitle"] = f"{len(group)} episodes · {len(seasons)} seasons"
        else:
            newest["subtitle"] = newest["subtitle"] + f" · {len(group)}×" if newest["subtitle"] else f"{len(group)}×"

        merged.append(newest)

    return merged


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default=os.path.expanduser("~/.config/arr-downloads/config.json"))
    parser.add_argument("--hours", type=int, default=24)
    parser.add_argument("--max-items", type=int, default=40)
    args = parser.parse_args()

    now = datetime.now(timezone.utc)
    since = now - timedelta(hours=args.hours)

    result = {"ok": True, "configured": False, "items": [], "counts": {}, "categories": [], "errors": []}

    try:
        config = load_config(args.config)
    except (OSError, json.JSONDecodeError) as e:
        result["ok"] = False
        result["error"] = f"Can't read {args.config}: {e}"
        print(json.dumps(result))
        return

    instances = [i for i in config.get("instances", []) if i.get("api_key") and i.get("url")]
    if not instances:
        result["error"] = "No instances configured with an API key yet."
        print(json.dumps(result))
        return

    result["configured"] = True
    category_order = []
    for instance in instances:
        category = instance.get("category") or DEFAULT_CATEGORY
        if category not in category_order:
            category_order.append(category)

    items = []
    for instance in instances:
        try:
            payload = fetch_history(instance, since)
        except (urllib.error.URLError, TimeoutError, ValueError) as e:
            result["errors"].append(f"{instance['name']}: {e}")
            continue
        records = payload if isinstance(payload, list) else payload.get("records", [])
        for record in records:
            item = parse_record(record, instance, now)
            if item:
                items.append(item)

    items.sort(key=lambda x: x["_sort"], reverse=True)

    counts = {}
    for item in items:
        counts[item["category"]] = counts.get(item["category"], 0) + 1

    items = group_items(items)[: args.max_items]
    for item in items:
        del item["_sort"]
        del item["_season_episode"]

    result["items"] = items
    result["counts"] = counts
    result["categories"] = [
        {"key": key, "label": CATEGORY_LABELS.get(key, key.title()), "count": counts.get(key, 0)}
        for key in category_order
    ]
    if result["errors"] and not items:
        result["ok"] = False
        result["error"] = "; ".join(result["errors"])

    print(json.dumps(result))


if __name__ == "__main__":
    main()
