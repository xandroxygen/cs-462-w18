<current-temp>
  <h4>Current Temperature:</h4>
  <h2><code>{ temp }</code></h2>

  <script>
    this.temp = store.currentTemp
    this.store.on("load", () => {
      this.temp = store.currentTemp
      this.update()
    })
  </script>
</current-temp>