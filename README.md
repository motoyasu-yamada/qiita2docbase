# 手順

## 記事をダウンロードして articles ディレクトリをここに置く
## 下記の設定ファイルを手で作成

```json:importes.json
{}
```

```json:credentials.json
{
  "COOKIE_STR": "Qiita-Teamにログイン済みのクッキー",
  "ACCESS_TOKEN":"docbaseのアクセストークン",
  "TEAM_DOMAIN": "liberapp",
  "GROUP_ID": 6394,
  "USER_IDS": {
    "Motoyasu-Yamada-Spicysoft" : 13353,
    "m_takegami":  13351,
    "akito_soma": 13366
  },
  "USER_ETC": 16733,
  "QIITA_TEAM": "spicysoft"
}
```

## 実行
```ruby main.rb```

# ディレクトリ構成
README.md
main.rb
articles/
credentials.json
imported.json
