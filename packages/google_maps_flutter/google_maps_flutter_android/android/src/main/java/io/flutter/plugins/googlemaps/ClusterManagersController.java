// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.googlemaps;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.model.BitmapDescriptor;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.maps.android.clustering.Cluster;
import com.google.maps.android.clustering.ClusterItem;
import com.google.maps.android.clustering.ClusterManager;
import com.google.maps.android.clustering.view.DefaultClusterRenderer;
import com.google.maps.android.collections.MarkerManager;
import io.flutter.plugins.googlemaps.Messages.MapsCallbackApi;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
/**
 * Controls cluster managers and exposes interfaces for adding and removing cluster items for
 * specific cluster managers.
 */
class ClusterManagersController
    implements GoogleMap.OnCameraIdleListener,
        ClusterManager.OnClusterClickListener<MarkerBuilder> {
  @NonNull private final Context context;
  @NonNull private final HashMap<String, ClusterManager<MarkerBuilder>> clusterManagerIdToManager;
  @NonNull private final MapsCallbackApi flutterApi;
  @Nullable private MarkerManager markerManager;
  @Nullable private GoogleMap googleMap;

  @Nullable
  private ClusterManager.OnClusterItemClickListener<MarkerBuilder> clusterItemClickListener;

  @Nullable
  private ClusterManagersController.OnClusterItemRendered<MarkerBuilder>
      clusterItemRenderedListener;

  ClusterManagersController(@NonNull MapsCallbackApi flutterApi, Context context) {
    this.clusterManagerIdToManager = new HashMap<>();
    this.context = context;
    this.flutterApi = flutterApi;
  }

  void init(GoogleMap googleMap, MarkerManager markerManager) {
    this.markerManager = markerManager;
    this.googleMap = googleMap;
  }

  void setClusterItemClickListener(
      @Nullable ClusterManager.OnClusterItemClickListener<MarkerBuilder> listener) {
    clusterItemClickListener = listener;
    initListenersForClusterManagers();
  }

  void setClusterItemRenderedListener(
      @Nullable ClusterManagersController.OnClusterItemRendered<MarkerBuilder> listener) {
    clusterItemRenderedListener = listener;
  }

  private void initListenersForClusterManagers() {
    for (Map.Entry<String, ClusterManager<MarkerBuilder>> entry :
        clusterManagerIdToManager.entrySet()) {
      initListenersForClusterManager(entry.getValue(), this, clusterItemClickListener);
    }
  }

  private void initListenersForClusterManager(
      ClusterManager<MarkerBuilder> clusterManager,
      @Nullable ClusterManager.OnClusterClickListener<MarkerBuilder> clusterClickListener,
      @Nullable ClusterManager.OnClusterItemClickListener<MarkerBuilder> clusterItemClickListener) {
    clusterManager.setOnClusterClickListener(clusterClickListener);
    clusterManager.setOnClusterItemClickListener(clusterItemClickListener);
  }

  /** Adds new ClusterManagers to the controller. */
  void addClusterManagers(@NonNull List<Messages.PlatformClusterManager> clusterManagersToAdd) {
    for (Messages.PlatformClusterManager clusterToAdd : clusterManagersToAdd) {
      addClusterManager(clusterToAdd.getIdentifier());
    }
  }




  @SuppressLint("NewApi")
  void addClusterManager(String clusterManagerId) {

    ClusterManager<MarkerBuilder> clusterManager =
            new ClusterManager<MarkerBuilder>(context, googleMap, markerManager);


    AsyncClusterIconRenderer<MarkerBuilder> renderer = new AsyncClusterIconRenderer<>(
            context,
            googleMap,
            clusterManager,
            clusterManagerId,
            ClusterManagersController.this,
            (clusterId, count, result) -> flutterApi.getBitmapForCluster(clusterId, (long) count, result)
    );



    initListenersForClusterManager(clusterManager,
            ClusterManagersController.this,
            clusterItemClickListener);
    clusterManager.setRenderer(renderer);
    clusterManagerIdToManager.put(clusterManagerId, clusterManager);
  }

  /** Removes ClusterManagers by given cluster manager IDs from the controller. */
  public void removeClusterManagers(@NonNull List<String> clusterManagerIdsToRemove) {
    for (String clusterManagerId : clusterManagerIdsToRemove) {
      removeClusterManager(clusterManagerId);
    }
  }

  /**
   * Removes the ClusterManagers by the given cluster manager ID from the controller. The reference
   * to this cluster manager is removed from the clusterManagerIdToManager and it will be garbage
   * collected later.
   */
  private void removeClusterManager(Object clusterManagerId) {
    // Remove the cluster manager from the hash map to allow it to be garbage collected.
    final ClusterManager<MarkerBuilder> clusterManager =
        clusterManagerIdToManager.remove(clusterManagerId);
    if (clusterManager == null) {
      return;
    }
    initListenersForClusterManager(clusterManager, null, null);
    clusterManager.clearItems();
    clusterManager.cluster();
  }

  /** Adds item to the ClusterManager it belongs to. */
  public void addItem(MarkerBuilder item) {
    ClusterManager<MarkerBuilder> clusterManager =
        clusterManagerIdToManager.get(item.clusterManagerId());
    if (clusterManager != null) {
      clusterManager.addItem(item);
      clusterManager.cluster();
    }
  }

  /** Removes item from the ClusterManager it belongs to. */
  public void removeItem(MarkerBuilder item) {
    ClusterManager<MarkerBuilder> clusterManager =
        clusterManagerIdToManager.get(item.clusterManagerId());
    if (clusterManager != null) {
      clusterManager.removeItem(item);
      clusterManager.cluster();
    }
  }

  /** Called when ClusterRenderer has rendered new visible marker to the map. */
  void onClusterItemRendered(@NonNull MarkerBuilder item, @NonNull Marker marker) {
    // If map is being disposed, clusterItemRenderedListener might have been cleared and
    // set to null.
    if (clusterItemRenderedListener != null) {
      clusterItemRenderedListener.onClusterItemRendered(item, marker);
    }
  }

  /** Reads clusterManagerId from object data. */
  @SuppressWarnings("unchecked")
  private static String getClusterManagerId(Object clusterManagerData) {
    Map<String, Object> clusterMap = (Map<String, Object>) clusterManagerData;
    // Ref: google_maps_flutter_platform_interface/lib/src/types/cluster_manager.dart ClusterManager.toJson() method.
    return (String) clusterMap.get("clusterManagerId");
  }

  /**
   * Requests all current clusters from the algorithm of the requested ClusterManager and converts
   * them to result response.
   */
  public @NonNull Set<? extends Cluster<MarkerBuilder>> getClustersWithClusterManagerId(
      String clusterManagerId) {
    ClusterManager<MarkerBuilder> clusterManager = clusterManagerIdToManager.get(clusterManagerId);
    if (clusterManager == null) {
      throw new Messages.FlutterError(
          "Invalid clusterManagerId",
          "getClusters called with invalid clusterManagerId:" + clusterManagerId,
          null);
    }
    return clusterManager.getAlgorithm().getClusters(googleMap.getCameraPosition().zoom);
  }

  @Override
  public void onCameraIdle() {
    for (Map.Entry<String, ClusterManager<MarkerBuilder>> entry :
        clusterManagerIdToManager.entrySet()) {
      entry.getValue().onCameraIdle();
    }
  }

  @Override
  public boolean onClusterClick(Cluster<MarkerBuilder> cluster) {
    if (cluster.getSize() > 0) {
      MarkerBuilder[] builders = cluster.getItems().toArray(new MarkerBuilder[0]);
      String clusterManagerId = builders[0].clusterManagerId();
      flutterApi.onClusterTap(
          Convert.clusterToPigeon(clusterManagerId, cluster), new NoOpVoidResult());
    }

    // Return false to allow the default behavior of the cluster click event to occur.
    return false;
  }

  /**
   * ClusterRenderer builds marker options for new markers to be rendered to the map. After cluster
   * item (marker) is rendered, it is sent to the listeners for control.
   */
  private static class ClusterRenderer<T extends MarkerBuilder> extends DefaultClusterRenderer<T> {
    private final ClusterManagersController clusterManagersController;

    public ClusterRenderer(
            Context context,
            GoogleMap map,
            ClusterManager<T> clusterManager,
            ClusterManagersController clusterManagersController) {
      super(context, map, clusterManager);
      this.clusterManagersController = clusterManagersController;
    }

    @Override
    protected void onBeforeClusterItemRendered(
        @NonNull T item, @NonNull MarkerOptions markerOptions) {
      // Builds new markerOptions for new marker created by the ClusterRenderer under
      // ClusterManager.
      item.update(markerOptions);
    }

    @Override
    protected void onClusterItemRendered(@NonNull T item, @NonNull Marker marker) {
      super.onClusterItemRendered(item, marker);
      clusterManagersController.onClusterItemRendered(item, marker);
    }
  }

  /** Interface for handling situations where clusterManager adds new visible marker to the map. */
  public interface OnClusterItemRendered<T extends ClusterItem> {
    void onClusterItemRendered(@NonNull T item, @NonNull Marker marker);
  }

  /**
   * A cluster renderer that supports asynchronous loading of cluster icons
   * while keeping default behavior for individual markers.
   */
  private static class AsyncClusterIconRenderer<T extends MarkerBuilder> extends ClusterRenderer<T> {
    private final Context context;
    private final String clusterId;
    private final ClusterIconProvider mClusterIconProvider;
    private final Handler mMainHandler;
    private final ConcurrentHashMap<String, BitmapDescriptor> mClusterIconCache;

    private interface ClusterIconProvider {
      void getBitmapForCluster(@NonNull String clusterId,
                               @NonNull int count,
                               @NonNull Messages.NullableResult<Messages.PlatformBitmap> result);
    }

    private interface IconCallback {
      void onIconLoaded(BitmapDescriptor icon);
    }

    public AsyncClusterIconRenderer(Context context,
                                    GoogleMap map,
                                    ClusterManager<T> clusterManager,
                                    String clusterId,
                                    ClusterManagersController clusterManagersController,
                                   AsyncClusterIconRenderer.ClusterIconProvider iconProvider) {
      super(context, map, clusterManager,clusterManagersController);
      mClusterIconProvider = iconProvider;
      this.context = context;
      this.clusterId = clusterId;

      mMainHandler = new Handler(Looper.getMainLooper());
      mClusterIconCache = new ConcurrentHashMap<>();
    }

    @Override
    protected void onBeforeClusterRendered(@NonNull Cluster<T> cluster,
                                           @NonNull MarkerOptions markerOptions) {
      String cacheKey = getClusterCacheKey(cluster);
      BitmapDescriptor cachedIcon = mClusterIconCache.get(cacheKey);

      if (cachedIcon != null) {
        markerOptions.icon(cachedIcon);
      } else {
        super.onBeforeClusterRendered(cluster, markerOptions);

        loadClusterIcon(cluster, icon -> {
          if (icon != null) {
            mClusterIconCache.put(cacheKey, icon);
            mMainHandler.post(() -> {
              Marker marker = getMarker(cluster);
              if (marker != null) {
                marker.setIcon(icon);
              }
            });
          }
        });
      }
    }

    @Override
    protected void onClusterUpdated(@NonNull Cluster<T> cluster, @NonNull Marker marker) {
      String cacheKey = getClusterCacheKey(cluster);
      BitmapDescriptor cachedIcon = mClusterIconCache.get(cacheKey);

      if (cachedIcon != null) {
        marker.setIcon(cachedIcon);
      } else {
        super.onClusterUpdated(cluster, marker);

        loadClusterIcon(cluster, icon -> {
          if (icon != null) {
            mClusterIconCache.put(cacheKey, icon);
            mMainHandler.post(() -> marker.setIcon(icon));
          }
        });
      }
    }

    private String getClusterCacheKey(Cluster<T> cluster) {
      return cluster.getPosition().toString() + "_" + cluster.getSize();
    }

    private void loadClusterIcon(Cluster<T> cluster, IconCallback callback) {
      int count = cluster.getSize();

      mClusterIconProvider.getBitmapForCluster(
              clusterId,
              count,
              new Messages.NullableResult<Messages.PlatformBitmap>() {
                @Override
                public void success(Messages.PlatformBitmap bitmap) {
                  if (bitmap != null) {
                    BitmapDescriptor descriptor = Convert.toBitmapDescriptor(
                            bitmap,
                            context.getAssets(),
                            context.getResources().getDisplayMetrics().density
                    );
                    callback.onIconLoaded(descriptor);
                  } else {
                    callback.onIconLoaded(null);
                  }
                }

                @Override
                public void error(Throwable throwable) {
                  callback.onIconLoaded(null);
                }
              }
      );
    }
  }
}



