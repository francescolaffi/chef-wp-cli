<?php

new SymlinkedPluginsUrlFixer;

/*
 * fix plugins_url call for symlinked plugins
 * fix activate_ and deactivate_ hooks for symlinked plugins
 * doesn't fix all plugin_basename calls
 */
class SymlinkedPluginsUrlFixer
{
  private $paths_map;

  public function __construct ()
  {
    $plugins_path = wp_get_active_and_valid_plugins();
    if (is_multisite()) {
      $plugins_path = array_merge($plugins_path, array_keys(wp_get_active_network_plugins()));
    }
    
    foreach ($plugins_path as $path) {
      $realpath = realpath($path);
      if ($path !== $realpath) {
        // remove common parts from the end
        while (basename($path) === basename($realpath)) {
          $path = dirname($path);
          $realpath = dirname($realpath);
        }
        $this->paths_map[$realpath] = $path;
      }
    }
    
    if (!empty($this->paths_map)) {
      add_filter('plugins_url', array($this, 'plugins_url_filter'), 10, 3);
    }
    add_action('activate_plugin', array($this, 'activate_plugin_action'), 10, 2);
    add_action('deactivate_plugin', array($this, 'deactivate_plugin_action'), 10, 2);
  }
  
  public function plugins_url_filter ($url, $path, $plugin)
  { 
    foreach ($this->paths_map as $source => $target) {
      if (strpos($plugin, $source) === 0) {
        return plugins_url($path, str_replace($source, $target, $plugin));
      }
    }
    
    return $url;
  }
  
  public function activate_plugin_action ($plugin)
  { 
    $this->fix_activate_deactivate_hook('activate', $plugin);
  }
  
  public function deactivate_plugin_action ($plugin)
  { 
    $this->fix_activate_deactivate_hook('deactivate', $plugin);
  }
  
  private function fix_activate_deactivate_hook ($action, $plugin)
  { 
    $file = WP_PLUGIN_DIR.'/'.$plugin;
    $realfile = realpath($file);
    
    if($file === $realfile) return;
    
    add_action($action.'_'.plugin_basename($file), function ($network_wide) use ($action, $realfile) {
      do_action($action.'_'.plugin_basename($realfile), $network_wide);
    });
  }
}