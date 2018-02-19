<profile-page>
  <form>
    <div class="row">
      <div class="six columns">
        <label for="sensor-name">Sensor Name</label>
        <input type="text" class="u-full-width" id="sensor-name" ref="name" value="{profile.name}">
      </div>
      <div class="six columns">
        <label for="sensor-location">Sensor Location</label>
        <input type="text" class="u-full-width" id="sensor-location" ref="location" value="{profile.location}">
      </div>    
    </div>
    <div class="row">
      <div class="six columns">
        <label for="contact-number">Contact Number</label>
        <input type="text" class="u-full-width" id="contact-number" ref="number" value="{profile.number}">
      </div>
      <div class="six columns">
        <label for="threshold">Sensor Location</label>
        <input type="text" class="u-full-width" id="threshold" ref="threshold" value="{profile.threshold}">
      </div>    
    </div>
    <input class="button-primary" type="submit" value="Submit" onclick="{submit}">
  </form>

  <script>
  this.profile = {
    name: "Wovyn 1",
    location: "Lamp Table",
    number: "+13852907346",
    threshold: "19.0"
  }
  

  this.submit = (e) => {
    const name = this.refs.name.value
    const location = this.refs.location.value
    const number = this.refs.number.value
    const threshold = this.refs.threshold.value
    this.profile = {
      name, location, number, threshold
    }
  }
  </script>
</profile-page>