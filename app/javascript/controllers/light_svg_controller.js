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
        }
      },

      // 新しいlightを背景に追加（遠方表現）
      addLight(color, amount = 1) {
        if (!this.container) return

        for (let i = 0; i < amount; i++) {
          const light = document.createElement('div')
          light.className = 'floating-light distant'
          light.style.background = color

          // 遠方のランダムな位置に配置（画面の端寄り）
          const margin = 100 // 画面端からのマージン
          const x = margin + Math.random() * (window.innerWidth - 2 * margin)
          const y = margin + Math.random() * (window.innerHeight - 2 * margin)
          light.style.setProperty('--start-x', x + 'px')
          light.style.setProperty('--start-y', y + 'px')
          light.style.left = x + 'px'
          light.style.top = y + 'px'

          this.container.appendChild(light)
          this.lights.push(light)
        }
      },

      // lightを画面奥に飛ばす
      flyLightToBackground(color) {
        if (!this.container) return

        const light = document.createElement('div')
        light.className = 'floating-light flying'
        light.style.background = color

        // 現在のlightの位置を取得
        const currentLight = document.getElementById('light')
        if (!currentLight) return

        const rect = currentLight.getBoundingClientRect()
        const centerX = rect.left + rect.width / 2
        const centerY = rect.top + rect.height / 2

        // 飛ぶ先の位置をランダムに決定（遠方）
        const margin = 100
        const flyX = margin + Math.random() * (window.innerWidth - 2 * margin)
        const flyY = margin + Math.random() * (window.innerHeight - 2 * margin)

        light.style.setProperty('--fly-x', (flyX - centerX) + 'px')
        light.style.setProperty('--fly-y', (flyY - centerY) + 'px')
        light.style.left = centerX + 'px'
        light.style.top = centerY + 'px'

        this.container.appendChild(light)

        // アニメーション終了後に背景漂うlightに変更（遠方表現）
        setTimeout(() => {
          if (light.parentNode) {
            light.classList.remove('flying')
            light.classList.add('distant')
            light.style.setProperty('--start-x', flyX + 'px')
            light.style.setProperty('--start-y', flyY + 'px')
            light.style.left = flyX + 'px'
            light.style.top = flyY + 'px'
            this.lights.push(light)
          }
        }, 1500)
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
    if (direction === 'left') {
      this.nextLight()
    } else {
      this.previousLight()
    }
  }

  handleSwipe(direction) {
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
    const currentLight = this.lightDefinitionsValue[this.currentIndexValue]
    const color = `rgba(${currentLight.r}, ${currentLight.g}, ${currentLight.b}, ${currentLight.a / 255})`

    // lightを画面奥に飛ばす
    if (this.floatingLightsManager) {
      this.floatingLightsManager.flyLightToBackground(color)
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
          this.triggerLightAnimation()
        }
      })
      .catch(error => {
        console.error('Error:', error)
      })
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