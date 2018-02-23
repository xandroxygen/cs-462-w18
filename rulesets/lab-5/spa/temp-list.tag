<temp-list>
  <h4>{ title }</h4>
  <table>
    <tr>
      <th>Temperature</th>
      <th>Time</th>
    </tr>
    <tr each={ temps }>
      <td><code>{ temperature }</code></td>
      <td><code>{ timestamp }</code></td>
    </tr>
  </table>

  <script>
    this.title = opts.title || "Temperature List"
    this.temps = store[opts.key]
    this.store.on('load', () => {
      this.temps = store[opts.key]
      this.update()
    })
  </script>
</temp-list>