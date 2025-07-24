<script lang="ts">
  import 'ol/ol.css';
  import MapViewer from './lib/MapViewer.svelte';
</script>

<main>
  <MapViewer />
</main>

<style>
  main {
    width: 100vw;
    height: 100vh;
    margin: 0;
    padding: 0;
    overflow: hidden;
  }

  :global(body) {
    margin: 0;
    padding: 0;
    overflow: hidden;
  }

  :global(html) {
    height: 100%;
  }
</style>
