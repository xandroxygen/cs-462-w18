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
    this.temps = [
    {
      temperature: "19.0",
      timestamp: "10:00"
    },
    {
      temperature: "19.1",
      timestamp: "10:01"
    }]
  </script>
</temp-list>