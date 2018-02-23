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
        <label for="threshold">Temperature Threshold</label>
        <input type="text" class="u-full-width" id="threshold" ref="threshold" value="{profile.threshold}">
      </div>    
    </div>
    <input class="button-primary" type="submit" value="Submit" onclick="{submit}">
  </form>

  <script>
  this.profile = {}
  
  this.submit = (e) => {
    const name = this.refs.name.value
    const location = this.refs.location.value
    const number = this.refs.number.value
    const threshold = this.refs.threshold.value
    this.profile = {
      name, location, number, threshold
    }
    updateProfile(this.profile).then(() => console.log("Profile updated"))
  }

  const profileUrl = "http://localhost:8080/sky/cloud/8cVyJ2vq9UMDoZVtHCqtpN/xandroxygen.sensor_profile"
  const updateProfileUrl = "http://localhost:8080/sky/event/8cVyJ2vq9UMDoZVtHCqtpN/VpvNikjsikJiTLrYnwMttZ/sensor/profile_updated"

  const updateProfile = async profile => {
    fetch(updateProfileUrl, {
      method: "POST",
      body: JSON.stringify(profile),
      headers: new Headers({
        "Content-Type": "application/json"
      })
    })
  }

  const getProfileData = async () => {
    const nameResponse = await fetch(`${profileUrl}/name`)
    const locationResponse = await fetch(`${profileUrl}/location`)
    const thresholdResponse = await fetch(`${profileUrl}/threshold`)
    const numberResponse = await fetch(`${profileUrl}/number`)

    const name = await nameResponse.json()
    const location = await locationResponse.json()
    const threshold = await thresholdResponse.json()
    const number = await numberResponse.json()

    return { name, location, threshold, number }
  }

  getProfileData().then(data => {
    this.profile = data
    this.update()
  })

  </script>
</profile-page>