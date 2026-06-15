import numpy as np
import matplotlib.pyplot as plt
import heapq
from scipy.ndimage import gaussian_filter
import time
import random

# Adjust Terrain Generation to Reflect Campus Data with Perlin Noise
def perlin_noise(width, height, scale, octaves=4, persistence=0.5 , elevation_ranges = [(4, 5), (4, 15), (8, 30)]):
    noise = np.zeros((height, width))
    
    for octave in range(octaves):
        freq = 2 ** octave
        amp = persistence ** octave
        for y in range(height):
            for x in range(width):
                noise[y][x] += generate_noise(x / (scale / freq), y / (scale / freq)) * amp
    
    # Normalize noise to be within 0 and 1
    noise = (noise - noise.min()) / (noise.max() - noise.min())

    # Apply Gaussian filter with a lower sigma value for less smoothing
    noise = gaussian_filter(noise, sigma=0.2)

    # Map normalized noise to selected elevation ranges with more variability
    terrain = np.zeros_like(noise)
    for elevation_min, elevation_max in elevation_ranges:
        mask = np.random.rand(*noise.shape) < 0.6  # Adjust mask threshold for more variability
        terrain[mask] = elevation_min + noise[mask] * (elevation_max - elevation_min)

    # Introduce random noise strength
    terrain += np.random.uniform(-1, 1, terrain.shape)  # Add a bit of random noise

    return terrain

gradient = np.random.rand(256, 256) * 2 - 1
# Perlin Noise Utility Functions
def generate_noise(x, y):
    x0, x1, y0, y1 = int(x) % 256, (int(x) + 1) % 256, int(y) % 256, (int(y) + 1) % 256
    sx, sy = fade(x - int(x)), fade(y - int(y))
    n0, n1 = dot_grid_gradient(x0, y0, x, y), dot_grid_gradient(x1, y0, x, y)
    ix0 = lerp(n0, n1, sx)
    n0, n1 = dot_grid_gradient(x0, y1, x, y), dot_grid_gradient(x1, y1, x, y)
    return lerp(ix0, lerp(n0, n1, sx), sy)

def fade(t):
    return t * t * t * (t * (t * 6 - 15) + 10)

def lerp(a, b, t):
    return a + t * (b - a)

def dot_grid_gradient(ix, iy, x, y):
    
    return gradient[ix][iy] * (x - ix) + gradient[ix][iy] * (y - iy)

# Hybrid Pathfinding with Quadtree-Style Efficiency
def hybrid_pathfinding(start, end, terrain, buildings, road_paths):
    rows, cols = terrain.shape
    open_set = []
    heapq.heappush(open_set, (0, start))
    came_from = {}
    g_score = {start: 0}
    f_score = {start: hybrid_heuristic(start, end, terrain)}

    while open_set:
        current = heapq.heappop(open_set)[1]
        if current == end:
            return reconstruct_path(came_from, current)
        
        # Get neighbors with boundary checks in get_neighbors
        for neighbor in get_neighbors(current, rows, cols, buildings, road_paths):
            # Ensure the neighbor is within bounds before accessing terrain
            if 0 <= neighbor[0] < rows and 0 <= neighbor[1] < cols:
                elevation_diff = abs(terrain[current] - terrain[neighbor])
                slope_penalty = elevation_diff / 50.0
                cost = 1 + slope_penalty

                if elevation_diff > 5:  # Use Dijkstra's when elevation changes are high
                    tentative_g_score = g_score[current] + cost
                else:  # Use A* otherwise
                    tentative_g_score = g_score[current] + 0.5 * cost

                if neighbor not in g_score or tentative_g_score < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g_score
                    f_score[neighbor] = tentative_g_score + hybrid_heuristic(neighbor, end, terrain)
                    heapq.heappush(open_set, (f_score[neighbor], neighbor))

    return []

def hybrid_heuristic(a, b, terrain):
    flat_heuristic = np.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2)
    terrain_factor = abs(terrain[a] - terrain[b]) / 10.0  # Consider elevation difference
    return flat_heuristic + terrain_factor

# Adjusted for Quadtree Partitioning and Restricted Zones
def get_neighbors(node, rows, cols, buildings, road_paths):
    x, y = node
    restricted_cells = set()
    
    # Add building restricted cells
    for bx, by, height in buildings:
        buffer_radius = max(1, height // 10)
        for dx in range(-buffer_radius, buffer_radius + 1):
            for dy in range(-buffer_radius, buffer_radius + 1):
                nx, ny = bx + dx, by + dy
                if 0 <= nx < rows and 0 <= ny < cols:
                    restricted_cells.add((nx, ny))
    
    # Add road restricted cells
    for (start, end) in road_paths:
        x0, y0 = start
        x1, y1 = end
        num_steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(num_steps + 1):
            rx = int(x0 + (x1 - x0) * i / num_steps)
            ry = int(y0 + (y1 - y0) * i / num_steps)
            if 0 <= rx < rows and 0 <= ry < cols:
                restricted_cells.add((rx, ry))
    
    # Define neighbors and exclude restricted cells
    neighbors = [(x-1, y), (x+1, y), (x, y-1), (x, y+1)]
    return [
        (nx, ny) for nx, ny in neighbors
        if 0 <= nx < rows and 0 <= ny < cols and (nx, ny) not in restricted_cells
    ]
def reconstruct_path(came_from, current):
    total_path = [current]
    while current in came_from:
        current = came_from[current]
        total_path.append(current)
    return total_path[::-1]

# Terrain and Water Flow Adaptation with Adjustable Rainfall
def adapt_terrain_with_water(terrain, rainfall_rate, absorption_rate, soil_infiltration_rate=15):
    adjusted_terrain = terrain - (rainfall_rate / (10.0 * (1 + absorption_rate)))
    absorption_factor = soil_infiltration_rate / 20.0
    return np.clip(adjusted_terrain - absorption_factor, 10, 30)

def calculate_slope(terrain):
    dx, dy = np.gradient(terrain)
    return np.sqrt(dx**2 + dy**2)



# Modified simulate_water_flow to randomize creek endpoint within a range
def simulate_water_flow(terrain, drainage_points, creek, creek_vicinity, rainfall_rate, absorption_rate, road_paths, soil_infiltration_rate=15):
    adjusted_terrain = adapt_terrain_with_water(terrain, rainfall_rate, absorption_rate, soil_infiltration_rate)
    slope = calculate_slope(adjusted_terrain)
    all_paths = []

    # Generate randomized creek targets within vicinity
    vicinity_points = [(creek[0] + dx, creek[1]) for dx in creek_vicinity]

    for start in drainage_points:
        # Select a random target point within the creek vicinity
        target = random.choice(vicinity_points)
        path = hybrid_pathfinding(start, target, adjusted_terrain, buildings, road_paths)
        all_paths.append(path)
    
    return adjusted_terrain, slope, all_paths

# Road Generation Function
def add_roads(terrain, road_paths, road_elevation=15):
    for (start, end) in road_paths:
        # Generate a linear path between start and end points for each road
        x0, y0 = start
        x1, y1 = end
        num_steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(num_steps + 1):
            x = int(x0 + (x1 - x0) * i / num_steps)
            y = int(y0 + (y1 - y0) * i / num_steps)
            terrain[x, y] = road_elevation  # Set road elevation
    return terrain

# Modified visualization to show roads
def visualize_paths_and_buildings(terrain, flood_area, paths, drainage_points, buildings, road_paths):
    flood_overlay = np.zeros((*terrain.shape, 4))
    flood_overlay[flood_area == 1] = [1, 0.65, 0, 0.5]
    plt.imshow(terrain, cmap='terrain')
    plt.colorbar()
    plt.imshow(flood_overlay, aspect='auto')

    # Plot roads
    for (start, end) in road_paths:
        x0, y0 = start
        x1, y1 = end
        plt.plot([y0, y1], [x0, x1], color="black", linewidth=2)  # Black lines for roads

    for path in paths:
        for (x, y) in path:
            plt.scatter(y, x, color='purple', s=15)
    for (x, y) in drainage_points:
        plt.scatter(y, x, color='purple', s=50, edgecolors='black', linewidth=1)
    for (x, y, height) in buildings:
        plt.scatter(y, x, color='red', s=80, marker='s', edgecolors='black', linewidth=1)
    plt.title("Terrain with Roads, Water Paths, Flood Areas, and Buildings")
    plt.show()

# Load and Display Terrain
def load_terrain(terrain_map):
    return np.array(terrain_map)  # Assuming 2D array representing terrain heights

def display_terrain(terrain):
    plt.imshow(terrain, cmap='terrain')
    plt.colorbar()
    plt.title("Terrain Map")
    plt.show()

def identify_flood_areas(terrain, rainfall_rate):
    flood_area = np.zeros_like(terrain)
    flood_area[terrain < (terrain.min() + rainfall_rate / 10)] = 1
    return flood_area

def calculate_slope_variation(path, terrain):
    if len(path) < 2:
        return 0  # Return 0 for paths that are too short to calculate variation
    slopes = [np.abs(terrain[path[i]] - terrain[path[i+1]]) for i in range(len(path) - 1)]
    return np.var(slopes)

def calculate_elevation_change(path, terrain):
    if len(path) < 2:
        return 0  # Handle empty path case
    return np.abs(terrain[path[0]] - terrain[path[-1]])

# Path Metrics
def calculate_path_length(path):
    return len(path)

def measure_flow_accumulation(terrain):
    flow_accumulation = np.zeros_like(terrain)
    for i in range(1, terrain.shape[0]-1):
        for j in range(1, terrain.shape[1]-1):
            neighbors = [(i-1, j), (i+1, j), (i, j-1), (i, j+1)]
            flow_accumulation[i, j] = sum([terrain[n] > terrain[i, j] for n in neighbors])
    return flow_accumulation

# Flood and Visualize
def evaluate_flood_reduction(original_flood_area, adjusted_flood_area):
    original_flood_count = np.sum(original_flood_area)
    adjusted_flood_count = np.sum(adjusted_flood_area)
    return (original_flood_count - adjusted_flood_count) / original_flood_count if original_flood_count else 0

def run_simulation(terrain_map, drainage_points, creek, rainfall_rate, absorption_rate, buildings):
    terrain = load_terrain(terrain_map)
    display_terrain(terrain)
    start_time = time.time()

    adjusted_terrain, slope, all_paths = simulate_water_flow(terrain, drainage_points, creek, creek_vicinity, rainfall_rate, absorption_rate, road_paths)
    flood_area = identify_flood_areas(adjusted_terrain, rainfall_rate)

    for path in all_paths:
        path_length = calculate_path_length(path)
        elevation_change = calculate_elevation_change(path, adjusted_terrain)
        slope_variation = calculate_slope_variation(path, adjusted_terrain)
        print(f"Path length: {path_length}")
        print(f"Elevation change: {elevation_change}")
        print(f"Slope variation: {slope_variation}")

    flow_accumulation = measure_flow_accumulation(adjusted_terrain)
    flood_reduction_ratio = evaluate_flood_reduction(terrain, flood_area)
    end_time = time.time()
    print(f"Simulation time: {end_time - start_time:.2f} seconds")
    print(f"Flow accumulation: {flow_accumulation}")
    print(f"Flood reduction ratio: {flood_reduction_ratio}")
    visualize_paths_and_buildings(adjusted_terrain, flood_area, all_paths, drainage_points, buildings, [])


# Example Usage with Adjustable Parameters
if __name__ == "__main__":
    width, height, scale = 100, 100, 30.0
    terrain_map = perlin_noise(width, height, scale)
    drainage_points = [(90, 90), (70, 80), (50, 60), (30, 50), (25, 40), 
                       (20, 30), (15, 20), (10, 10), (5, 5), (55, 10)]
    creek = (55, 1)
    creek_vicinity = range(-30, 31, 20)  # Defines points around (55, 1) as (25, 1), (45, 1), (65, 1), etc.
    rainfall_rate, absorption_rate = 20, 0.75
    buildings = [ (85, 45, 10), (85, 60, 10), (70, 60, 10),(70, 75, 10),(60, 75, 10), (35, 88, 10),(32, 45, 10),  (60, 40, 10),(60, 50, 10),(45, 50, 10), (43, 48, 10), (38, 48, 10), (43, 40, 10), (60, 60, 10), (58, 62, 10)]
    
    # Define some road paths between building locations (or arbitrary points)
    road_paths = [
       ((50, 20), (50, 85)),((65, 55), (65, 85)),((53, 55), (90, 55)),((38, 88), (65, 88)) ,((36, 44), (48, 44)) # New vertical road spanning the map's width at x=55
]
     
    terrain_map = add_roads(terrain_map, road_paths)

    run_simulation(terrain_map, drainage_points, creek, rainfall_rate, absorption_rate, buildings)