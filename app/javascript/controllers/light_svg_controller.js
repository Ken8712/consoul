import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["svg", "light"]
  static values = {
    lightDefinitions: Array,
    userLights: Array,
    currentIndex: { type: Number, default: 0 },
    startX: { type: Number, default: 0 },
    startY: { type: Number, default: 0 },
    startTime: { type: Number, default: 0 }
  }

  connect() {
    this.isInteractionDisabled = false
    this.hasShownAccumulatedLights = false
    this.initFloatingLightsManager()
    this.setupTouchEvents()
    this.updateLightColor()
    // 初回読み込み時は既存の感情を表示しない
    // this.loadExistingLights()
  }

  disconnect() {
    // クリーンアップ
    if (this.floatingLightsManager) {
      this.floatingLightsManager.cleanup()
    }
  }

  initFloatingLightsManager() {
    this.floatingLightsManager = {
      container: null,
      lights: [],
      accumulatedLights: [],

      init() {
        this.container = document.getElementById('floating-lights-container')
        if (!this.container) {
          console.error('floating-lights-container not found')
          return false
        }
        return true
      },

      cleanup() {
        if (this.container) {
          this.container.innerHTML = ''
          this.lights = []
          this.accumulatedLights = []
        }
      },

      // 放物線の軌道を計算
      calculateProjectilePath(startX, startY, targetX, targetY) {
        const midX = (startX + targetX) / 2
        const midY = Math.min(startY, targetY) - 150 // 画面中央上部を頂点とする

        return {
          quarter: {
            x: startX + (midX - startX) * 0.5,
            y: startY + (midY - startY) * 0.5
          },
          half: {
            x: midX,
            y: midY
          },
          threeQuarter: {
            x: midX + (targetX - midX) * 0.5,
            y: midY + (targetY - midY) * 0.5
          },
          final: {
            x: targetX,
            y: targetY
          }
        }
      },

      // 新しいライトを放物線軌道で投射
      projectLightToBackground(color, callback) {
        if (!this.container) return

        const light = document.createElement('div')
        light.className = 'floating-light projecting'
        light.style.background = color

        // 現在のlightの位置を取得
        const currentLight = document.getElementById('light')
        if (!currentLight) return

        const rect = currentLight.getBoundingClientRect()
        const startX = rect.left + rect.width / 2
        const startY = rect.top + rect.height / 2

        // 着地点をランダムに決定（画面上部中央寄り）
        const margin = 100
        const targetX = margin + Math.random() * (window.innerWidth - 2 * margin)
        const targetY = margin + Math.random() * (window.innerHeight * 0.4) // 画面上部40%の範囲

        // 放物線軌道を計算
        const path = this.calculateProjectilePath(startX, startY, targetX, targetY)

        // CSS変数として軌道を設定
        light.style.setProperty('--flight-x-quarter', (path.quarter.x - startX) + 'px')
        light.style.setProperty('--flight-y-quarter', (path.quarter.y - startY) + 'px')
        light.style.setProperty('--flight-x-half', (path.half.x - startX) + 'px')
        light.style.setProperty('--flight-y-half', (path.half.y - startY) + 'px')
        light.style.setProperty('--flight-x-three-quarter', (path.threeQuarter.x - startX) + 'px')
        light.style.setProperty('--flight-y-three-quarter', (path.threeQuarter.y - startY) + 'px')
        light.style.setProperty('--flight-x-final', (targetX - startX) + 'px')
        light.style.setProperty('--flight-y-final', (targetY - startY) + 'px')

        light.style.left = startX + 'px'
        light.style.top = startY + 'px'

        this.container.appendChild(light)

        // アニメーション終了後に背景の一部として固定
        setTimeout(() => {
          if (light.parentNode) {
            light.classList.remove('projecting')
            light.classList.add('distant')
            light.style.setProperty('--start-x', targetX + 'px')
            light.style.setProperty('--start-y', targetY + 'px')
            light.style.left = targetX + 'px'
            light.style.top = targetY + 'px'
            this.lights.push(light)
            
            // コールバック実行
            if (callback) callback()
          }
        }, 2000)
      },

      // 蓄積されたライトを同心円状にフェードイン表示
      showAccumulatedLights(userLights, isRippleEffect = false) {
        if (!this.container || !userLights) return

        // 中心点（画面中央）
        const centerX = window.innerWidth / 2
        const centerY = window.innerHeight / 2

        userLights.forEach((userLight, index) => {
          if (userLight.amount > 0) {
            const color = `rgba(${userLight.light_definition.r}, ${userLight.light_definition.g}, ${userLight.light_definition.b}, ${userLight.light_definition.a / 255})`
            
            for (let i = 0; i < userLight.amount; i++) {
              const light = document.createElement('div')
              light.className = `accumulated-light ${isRippleEffect ? 'ripple-light' : ''}`
              light.style.background = color

              // 同心円状に配置
              const radius = 100 + (i * 50) // 中心から100px開始、50pxずつ離れる
              const angle = (index * (360 / userLights.length)) + (i * 15) // 種類ごとに角度オフセット
              const radian = (angle * Math.PI) / 180

              const x = centerX + Math.cos(radian) * radius
              const y = centerY + Math.sin(radian) * radius

              light.style.left = x + 'px'
              light.style.top = y + 'px'
              light.style.width = '40px'
              light.style.height = '40px'

              // 順次フェードイン（波紋効果）
              light.style.animationDelay = `${(i + index) * 0.1}s`

              this.container.appendChild(light)
              this.accumulatedLights.push(light)
            }
          }
        })
      },

      // 既存のlightを背景に配置（遠方表現）
      loadExistingLights(userLights) {
        if (!this.container || !userLights) return

        userLights.forEach(userLight => {
          if (userLight.amount > 0) {
            const color = `rgba(${userLight.light_definition.r}, ${userLight.light_definition.g}, ${userLight.light_definition.b}, ${userLight.light_definition.a / 255})`
            this.addLight(color, userLight.amount)
          }
        })
      },

      // 新しいlightを背景に追加（遠方表現）
      addLight(color, amount = 1) {
        if (!this.container) return

        for (let i = 0; i < amount; i++) {
          const light = document.createElement('div')
          light.className = 'floating-light distant'
          light.style.background = color

          // 遠方のランダムな位置に配置（画面の端寄り）
          const margin = 100
          const x = margin + Math.random() * (window.innerWidth - 2 * margin)
          const y = margin + Math.random() * (window.innerHeight - 2 * margin)
          light.style.setProperty('--start-x', x + 'px')
          light.style.setProperty('--start-y', y + 'px')
          light.style.left = x + 'px'
          light.style.top = y + 'px'

          this.container.appendChild(light)
          this.lights.push(light)
        }
      }
    }

    // 初期化
    if (!this.floatingLightsManager.init()) {
      console.error('Failed to initialize floating lights manager')
    }
  }

  setupTouchEvents() {
    this.svgTarget.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
    this.svgTarget.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
    this.svgTarget.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false })
  }

  handleTouchStart(event) {
    event.preventDefault()
    // event.touches[0]はタッチの座標を取得するので、これを使ってstartXValueとstartYValueを設定する
    const touch = event.touches[0]
    this.startXValue = touch.clientX
    this.startYValue = touch.clientY
    // startTimeValueはタッチ開始時の時刻を取得する。時間を取得することで、フリックやスワイプの判定に使用する。具体的には、フリックの場合は、タッチ開始からの経過時間を取得することで、フリックの速度を判定する。速度の調整は、deltaTimeの値の条件を調整することで行う。
    this.startTimeValue = Date.now()
  }

  handleTouchMove(event) {
    event.preventDefault()
  }

  handleTouchEnd(event) {
    event.preventDefault()
    const touch = event.changedTouches[0]
    const deltaX = touch.clientX - this.startXValue
    const deltaY = touch.clientY - this.startYValue
    const deltaTime = Date.now() - this.startTimeValue

    // フリック判定（水平方向の移動が大きい場合）
    // 50はフリックの最小移動距離、300はフリックの最大時間。これらの値を調整することで、フリックの速度を調整する。Math.abs(deltaX)はdeltaXの絶対値を取得する。離した距離が50より大きい場合はフリックと判定する。deltaTimeはタッチ開始からの経過時間を取得する。この時間が300ミリ秒より小さい場合はフリックと判定する。話さない場合は
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50 && deltaTime < 300) {
      this.handleFlick(deltaX > 0 ? 'right' : 'left')
    }
    // スワイプ判定（垂直方向の移動が大きい場合）
    else if (Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > 50) {
      this.handleSwipe(deltaY > 0 ? 'down' : 'up')
    }
  }

  handleFlick(direction) {
    // インタラクション無効化中は何もしない
    if (this.isInteractionDisabled) {
      return
    }

    if (direction === 'left') {
      this.nextLight()
    } else {
      this.previousLight()
    }
  }

  handleSwipe(direction) {
    // インタラクション無効化中は何もしない
    if (this.isInteractionDisabled) {
      return
    }

    if (direction === 'up') {
      this.executeAction()
    }
  }

  nextLight() {
    this.currentIndexValue = (this.currentIndexValue + 1) % this.lightDefinitionsValue.length
    this.updateLightColor()
  }

  previousLight() {
    this.currentIndexValue = this.currentIndexValue === 0
      ? this.lightDefinitionsValue.length - 1
      : this.currentIndexValue - 1
    this.updateLightColor()
  }

  executeAction() {
    // インタラクション無効化中は何もしない
    if (this.isInteractionDisabled) {
      return
    }

    const currentLight = this.lightDefinitionsValue[this.currentIndexValue]
    const color = `rgba(${currentLight.r}, ${currentLight.g}, ${currentLight.b}, ${currentLight.a / 255})`

    // インタラクションを無効化
    this.disableInteraction()

    // 放物線軌道でライトを投射
    if (this.floatingLightsManager) {
      this.floatingLightsManager.projectLightToBackground(color, () => {
        // 投射完了後の処理
        if (!this.hasShownAccumulatedLights) {
          // 初回は波紋効果で蓄積ライトを表示
          this.floatingLightsManager.showAccumulatedLights(this.userLightsValue, true)
          this.hasShownAccumulatedLights = true
        }

        // 新しいライトを画面下に配置
        this.spawnNewLight()
        
        // インタラクションを再有効化
        this.enableInteraction()
      })
    }

    // サーバーにLight増加リクエストを送信
    fetch('/api/lights/increment', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        light_key: currentLight.key
      })
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          // userLightsValueを更新
          this.updateUserLightsValue(currentLight.key)
        }
      })
      .catch(error => {
        console.error('Error:', error)
        // エラー時もインタラクションを再有効化
        this.enableInteraction()
      })
  }

  // インタラクション無効化
  disableInteraction() {
    this.isInteractionDisabled = true
    this.element.classList.add('interaction-disabled')
  }

  // インタラクション有効化
  enableInteraction() {
    this.isInteractionDisabled = false
    this.element.classList.remove('interaction-disabled')
  }

  // 新しいライトを画面下に配置
  spawnNewLight() {
    // 現在のライトを一時的に隠して新しいライトを表示
    this.lightTarget.style.opacity = '0'
    
    setTimeout(() => {
      this.lightTarget.style.opacity = '1'
      this.triggerLightAnimation()
    }, 500)
  }

  // userLightsValueを更新
  updateUserLightsValue(lightKey) {
    const existingLight = this.userLightsValue.find(light => 
      light.light_definition.key === lightKey
    )
    
    if (existingLight) {
      existingLight.amount += 1
    } else {
      const lightDef = this.lightDefinitionsValue.find(def => def.key === lightKey)
      if (lightDef) {
        this.userLightsValue.push({
          amount: 1,
          light_definition: lightDef
        })
      }
    }
  }

  updateLightColor() {
    const currentLight = this.lightDefinitionsValue[this.currentIndexValue]
    const color = `rgba(${currentLight.r}, ${currentLight.g}, ${currentLight.b}, ${currentLight.a / 255})`

    // SVGのグラデーションを更新
    const gradient = this.svgTarget.querySelector('#lightGrad')
    const stops = gradient.querySelectorAll('stop')

    stops[0].setAttribute('stop-color', color)
    stops[0].setAttribute('stop-opacity', '1.0')
    stops[1].setAttribute('stop-color', color)
    stops[1].setAttribute('stop-opacity', '0.6')
    stops[2].setAttribute('stop-color', color)
    stops[2].setAttribute('stop-opacity', '0')
  }

  triggerLightAnimation() {
    // アニメーションをリセットして再実行
    this.lightTarget.style.animation = 'none'
    this.lightTarget.offsetHeight // リフローを強制

    // 新しいアニメーションを設定
    this.lightTarget.style.animation = 'float 0.8s ease-in-out infinite'

    // パルスアニメーションが終了したら通常のアニメーションに戻す
    setTimeout(() => {
      this.lightTarget.style.animation = 'float 0.8s ease-in-out infinite'
    }, 500)
  }

  loadExistingLights() {
    if (this.floatingLightsManager && this.userLightsValue) {
      this.floatingLightsManager.loadExistingLights(this.userLightsValue)
    }
  }
} 