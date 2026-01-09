//
//  PageStrokeView.swift
//  NISDK3_Example
//
//  Created by NeoLAB on 2020/04/07.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import CoreGraphics
import NISDK3

class PageStrokeView: UIView {

    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    
    var dotPath = UIBezierPath()
    var shapelayer: CAShapeLayer!
    var x:Double = 0.0
    var y:Double = 0.0
    var width:Double = 0.0
    var height:Double = 0.0
    
    //HoverView
    var hoverLayer: CAShapeLayer!
    var hoverPath: UIBezierPath!
    private var hoverRadius = CGFloat(5)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewinit()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            checkServerConnection()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        viewinit()
    }
    
    
    private let connectionIndicator: UIView = {
        let view = UIView(frame: CGRect(x: 355, y: 0, width: 10, height: 10))
        view.backgroundColor = .red  // Начальный цвет — красный
        view.layer.cornerRadius = 5  // Идеальный кружок
        view.clipsToBounds = true
        view.isHidden = false  // Или true, если хочешь скрыть по умолчанию
        view.translatesAutoresizingMaskIntoConstraints = true
        return view
    }()
    
    enum ConnectionStatus {
        case disconnected   // красный
        case connected      // синий
        case successFlash   // зелёный на 0.3 сек
    }
    
    func viewinit(){
        backgroundColor = UIColor.clear
        isMultipleTouchEnabled = false
        UIGraphicsBeginImageContext(frame.size)
        shapelayer = CAShapeLayer()
        shapelayer.lineWidth = 1
        shapelayer.strokeColor = UIColor.black.cgColor
        shapelayer.fillColor = UIColor.clear.cgColor
        shapelayer.lineCap = CAShapeLayerLineCap.round
        layer.addSublayer(shapelayer)
        
        //HoverView
        hoverLayer = CAShapeLayer()
        layer.addSublayer(hoverLayer)
        
        // === ДОБАВЛЯЕМ ИНДИКАТОР СОЕДИНЕНИЯ ===
            addSubview(connectionIndicator)
        connectionIndicator.translatesAutoresizingMaskIntoConstraints = true;
            // Constraints для правильного позиционирования (правый верхний угол)
            NSLayoutConstraint.activate([
                connectionIndicator.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: -16),
                connectionIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -160),
                connectionIndicator.widthAnchor.constraint(equalToConstant: 10),
                connectionIndicator.heightAnchor.constraint(equalToConstant: 10)
            ])
            
            // Начальное состояние — красный
            updateConnectionIndicator(.disconnected)
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkServerConnection()
        }
    }
    
    func updateConnectionIndicator(_ status: ConnectionStatus) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.2) {
                switch status {
                case .disconnected:
                    self.connectionIndicator.backgroundColor = .red
                case .connected:
                    self.connectionIndicator.backgroundColor = .systemBlue
                case .successFlash:
                    self.connectionIndicator.backgroundColor = .systemGreen
                }
            }
            
            if status == .successFlash {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.checkServerConnection()
                }
            }
        }
    }
    
    func checkServerConnection() {
        let defaultBaseURL = "91.197.0.41:5252"
        let savedBaseURL = UserDefaults.standard.string(forKey: "ServerBaseURL") ?? defaultBaseURL
        var fullURLString = "http://\(savedBaseURL)/health"
        
        if savedBaseURL.hasPrefix("http://") || savedBaseURL.hasPrefix("https://") {
            fullURLString = "\(savedBaseURL)/health"
        }
        
        guard let url = URL(string: fullURLString) else {
            DispatchQueue.main.async {
                self.updateConnectionIndicator(.disconnected)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            // ВСЁ, что меняет UI — только в main!
            DispatchQueue.main.async {
                if error != nil {
                    self.updateConnectionIndicator(.disconnected)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 405 {  // 405 тоже нормально — метод не поддерживается, но сервер жив
                    self.updateConnectionIndicator(.connected)
                } else {
                    self.updateConnectionIndicator(.disconnected)
                }
            }
        }.resume()
    }
    
    //Second Dot data
    func addDot(_ dot: Dot) {
        DispatchQueue.main.async {
            self.hoverLayer.removeFromSuperlayer() //remove hover when draw stroke

            let type = dot.dotType
            let pointXY = ScaleHelper.shared.getPoint(dot, self.frame.size)
            switch type {
            case .Down:
                self.dotPath.move(to: pointXY)
            case .Move:
                self.dotPath.addLine(to: pointXY)
                self.shapelayer.path = self.dotPath.cgPath
                
            case .Up:
                self.dotPath.removeAllPoints()
                break
            }
        }

        // Отправка точки на сервер в реальном времени
        let pointJSON: [String: Any] = [
            "x": dot.x,
            "y": dot.y,
            "force": dot.force,
            "time": dot.time,
            "dotType": dot.dotType.rawValue,  // 0-Down, 1-Move, 2-Up
            "page": dot.pageInfo.page,
            "section": dot.pageInfo.section,
            "owner": dot.pageInfo.owner ,
            "note": dot.pageInfo.note
        ]

        // Получаем адрес сервера из настроек (UserDefaults)
        let defaultBaseURL = "91.197.0.41:5252"  // Значение по умолчанию
        let savedBaseURL = UserDefaults.standard.string(forKey: "ServerBaseURL") ?? defaultBaseURL

        // Формируем полный URL: http://IP:порт/api/dot
        var fullURLString = "http://\(savedBaseURL)/api/dot"

        // Если пользователь ввёл полный URL с http/https — используем как есть
        if savedBaseURL.hasPrefix("http://") || savedBaseURL.hasPrefix("https://") {
            fullURLString = "\(savedBaseURL)/api/dot"
        }

        guard let url = URL(string: fullURLString) else {
            print("Ошибка: некорректный URL сервера — \(fullURLString)")
            return
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: pointJSON) else {
            print("Ошибка сериализации JSON")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Ошибка отправки точки: \(error.localizedDescription)")
                self.checkServerConnection()
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Точка успешно отправлена")
                self.updateConnectionIndicator(.successFlash)
            } else {
                print("Сервер ответил с ошибкой")
                self.updateConnectionIndicator(.disconnected)
            }
        }.resume()
    }
    
    //MARK: HoverView
    func addHoverLayout(_ dot: Dot) {
        DispatchQueue.main.async {
            let len = self.hoverRadius
            let currentLocation = ScaleHelper.shared.getPoint(dot, self.frame.size)
            
            let path = UIBezierPath(arcCenter: currentLocation, radius: len, startAngle: 0, endAngle: .pi * 2.0, clockwise: true)
            
            self.hoverLayer.path = path.cgPath
            self.hoverLayer.fillColor = UIColor.orange.cgColor
            self.hoverLayer.strokeColor = UIColor.yellow.cgColor
            self.hoverLayer.lineWidth = self.hoverRadius * 0.05
            self.hoverLayer.opacity = 0.6
            self.layer.addSublayer(self.hoverLayer)
            
        }
    }
}
