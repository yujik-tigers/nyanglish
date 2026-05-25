//
//  AnimatedGIFView.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/22/26.
//

import SwiftUI
import WebKit

struct AnimatedGIFView: UIViewRepresentable {
    let resourceName: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedResourceName != resourceName,
              let gifURL = Bundle.main.url(forResource: resourceName, withExtension: "gif") else {
            return
        }

        context.coordinator.loadedResourceName = resourceName

        let html = """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                html, body {
                    margin: 0;
                    width: 100%;
                    height: 100%;
                    background: transparent;
                    overflow: hidden;
                }
                body {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                img {
                    max-width: 100%;
                    max-height: 100%;
                    object-fit: contain;
                }
            </style>
        </head>
        <body>
            <img src="\(gifURL.lastPathComponent)" alt="">
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: gifURL.deletingLastPathComponent())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadedResourceName: String?
    }
}
