# Promise

Swift で実装された軽量かつスレッドセーフな Promise/Future ライブラリです。

Promise の目標は次の 3 つです。

- 低オーバーヘッド: 状態を 1 つのロックで管理し、解決後の追加アロケーションなし
- 豊富な API: Combine や Swift Concurrency に似た演算子群
- 連携の容易さ: Combine、async/await、GCD、URLSession とのブリッジを標準装備



---



## 特長

- 直感的なチェイニング (`map`, `flatMap`, `catch`, `finally`, `timeout`, `wait` など)
- 値・エラー変換用オペレーター
- `merge`, `combine`, `combineAll` などの競合・結合ヘルパー
- Swift Concurrency 連携 (`promise.value`, デタッチドタスク, `Task.promise`)
- Combine 連携 (`promise.publisher()`, `Publisher.firstValue()`)
- GCD ヘルパー（キュー上での実行や遅延配信）
- URLSession ラッパー (`session.fetch`, `session.data`)
- デバッグ支援 (`print`, `measureInterval`, `breakpointOnError`)
- 未解決のまま解放された場合にエラーを投げる Resolver/Rejector
- Sendable 対応
- 追加依存なし



---



## 必要環境

| プラットフォーム | 最低バージョン |
| ---------------- | -------------- |
| iOS              | 12.0           |
| macOS            | 10.15          |
| tvOS             | 12.0           |
| watchOS          | 4.0            |

Swift 6 以上、Xcode 17 以上を推奨します。



---



## インストール方法

### Swift Package Manager

Xcode の「Package Dependencies」に次の URL を追加してください。
```

https://github.com/ObuchiYuki/Promise.git

```
または `Package.swift` に記述します。

```swift
.package(url: "https://github.com/ObuchiYuki/Promise.git", from: "1.0.0")
```

ターゲット依存関係の例:

```swift
.target(
    name: "YourApp",
    dependencies: ["Promise"]
)
```



------



## クイックスタート

```swift
// URLSession を Promise でラップ
func loadImage(from url: URL) -> Promise<UIImage, Error> {
    URLSession.shared.data(for: url)
        .map(UIImage.init(data:))
        .tryMap { image -> UIImage in
            guard let image else { throw URLError(.cannotDecodeContentData) }
            return image
        }
}

// Combine 風に使用
loadImage(from: url)
    .timeout(5)
    .peek { print("画像サイズ: \($0.size)") }
    .catch { print("失敗:", $0) }

// async/await で使用
let image = try await loadImage(from: url).value
```



------



## ライセンス

Promise は MIT License の下で公開されています。
詳しくは `LICENSE` ファイルを参照してください。
