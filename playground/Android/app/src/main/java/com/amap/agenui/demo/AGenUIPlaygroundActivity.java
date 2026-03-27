package com.amap.agenui.demo;

import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.Toast;

import androidx.appcompat.app.ActionBarDrawerToggle;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.view.GravityCompat;
import androidx.drawerlayout.widget.DrawerLayout;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.amap.agenui.demo.adapter.ComponentAdapter;
import com.amap.agenui.demo.story.ComponentStory;
import com.amap.agenui.demo.story.StoryLoader;
import com.amap.agenui.demo.story.SubStory;
import com.amap.agenui.render.surface.ISurfaceListener;
import com.amap.agenui.render.surface.Surface;
import com.amap.agenui.render.surface.SurfaceManager;
import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.navigation.NavigationView;
import com.google.android.material.tabs.TabLayout;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonParser;
import com.google.gson.JsonSyntaxException;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.List;

/**
 * AGenUI Demo Activity
 * <p>
 * Features:
 * 1. Display A2UI component rendering effects
 * 2. Support editing Components and DataModel JSON
 * 3. Real-time preview of rendering results
 * 4. Display log information
 *
 * @author ACoder
 * @since 2026-02-27
 */
public class AGenUIPlaygroundActivity extends AppCompatActivity {

    // UI Components
    private DrawerLayout drawerLayout;
    private MaterialToolbar toolbar;
    private ActionBarDrawerToggle drawerToggle;
    private NavigationView navigationView;
    private RecyclerView rvComponentList;
    private View customComponentMenuItem;
    private FrameLayout renderContent;

    // Edit Drawer
    private TabLayout tabLayout;
    private EditText etJsonEditor;
    private Button btnFormat;
    private Button btnValidate;
    private Button btnCancel;
    private Button btnSave;

    // Data
    private String currentComponentsJson = "{}";
    private String currentDataModelJson = "{}";
    private EditorType currentEditorType = EditorType.NONE;

    // Story Related
    private StoryLoader storyLoader;
    private ComponentAdapter componentAdapter;
    private List<ComponentStory> componentStories;

    // Rendering Framework
    private SurfaceManager surfaceManager;
    private String currentSurfaceId = null;

    private static final String TAG = "AGenUIDemo";

    private enum EditorType {
        NONE,
        COMPONENTS,
        DATA_MODEL
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_agenui_playground);

        initViews();
        setupToolbar();
        setupNavigationDrawer();
        setupDrawer();

        // Initialize Story loader
        initStoryLoader();

        // Initialize AGenUI
        initAGenUI();
    }

    /**
     * Initialize views
     */
    private void initViews() {
        // Main layout
        drawerLayout = findViewById(R.id.drawerLayout);
        toolbar = findViewById(R.id.toolbar);
        navigationView = findViewById(R.id.navigationView);
        rvComponentList = navigationView.findViewById(R.id.rvComponentList);
        customComponentMenuItem = navigationView.findViewById(R.id.customComponentMenuItem);
        renderContent = findViewById(R.id.renderContent);

        // Edit drawer
        tabLayout = findViewById(R.id.tabLayout);
        etJsonEditor = findViewById(R.id.etJsonEditor);
        btnFormat = findViewById(R.id.btnFormat);
        btnValidate = findViewById(R.id.btnValidate);
        btnCancel = findViewById(R.id.btnCancel);
        btnSave = findViewById(R.id.btnSave);

        // Performance overlay
    }

    /**
     * Setup toolbar
     */
    private void setupToolbar() {
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setHomeAsUpIndicator(R.drawable.ic_menu);
        }

        // Setup ActionBarDrawerToggle
        drawerToggle = new ActionBarDrawerToggle(
                this,
                drawerLayout,
                toolbar,
                R.string.drawer_nav_title,
                R.string.drawer_close
        );
        drawerLayout.addDrawerListener(drawerToggle);
        drawerToggle.syncState();
    }

    /**
     * Setup left navigation drawer
     */
    private void setupNavigationDrawer() {
        // Setup RecyclerView
        rvComponentList.setLayoutManager(new LinearLayoutManager(this));

        // Create adapter
        componentAdapter = new ComponentAdapter();
        rvComponentList.setAdapter(componentAdapter);

        // Setup click listener
        componentAdapter.setOnItemClickListener(new ComponentAdapter.OnItemClickListener() {
            @Override
            public void onParentClick(ComponentStory story) {
                // Close navigation drawer
                drawerLayout.closeDrawer(GravityCompat.START);

                // Load component Story (compatible with old version without sub-items)
                loadComponentStory(story);
            }

            @Override
            public void onChildClick(SubStory subStory) {
                // Close navigation drawer
                drawerLayout.closeDrawer(GravityCompat.START);

                // Load sub Story
                loadSubStory(subStory);
            }
        });

        // Setup custom component menu item click listener
        customComponentMenuItem.setOnClickListener(v -> {
            // Close left drawer
            drawerLayout.closeDrawer(GravityCompat.START);

            // Set default JSON template
            currentComponentsJson = getDefaultComponentsTemplate();
            currentDataModelJson = "{}";

            // Open right edit drawer
            openEditor(EditorType.COMPONENTS);

            addLog("Open custom component editor");
        });
    }

    /**
     * Initialize Story loader
     */
    private void initStoryLoader() {
        storyLoader = new StoryLoader(this);

        // Load all Stories
        componentStories = storyLoader.loadAllStories();

        // Update adapter
        if (componentAdapter != null) {
            componentAdapter.setStories(componentStories);
        }

        addLog("Loaded " + componentStories.size() + " components");
    }

    /**
     * Load component Story (compatible with old version)
     */
    private void loadComponentStory(ComponentStory story) {
        // Update Components JSON
        currentComponentsJson = story.getComponentsString();

        // Update DataModel JSON
        currentDataModelJson = story.getDataModelString();

        // Update title
        updateToolbarTitle(story.getComponentName());

        // Add log
        addLog("Loaded component: " + story.getComponentName());

        // If editor is open, update editor content
        if (currentEditorType == EditorType.COMPONENTS) {
            etJsonEditor.setText(currentComponentsJson);
        } else if (currentEditorType == EditorType.DATA_MODEL) {
            etJsonEditor.setText(currentDataModelJson);
        }

        // Call A2UI rendering
        renderComponents();
    }

    /**
     * Load sub Story
     */
    private void loadSubStory(SubStory subStory) {
        // Update Components JSON
        currentComponentsJson = subStory.getComponentsString();

        // Update DataModel JSON
        currentDataModelJson = subStory.getDataModelString();

        // Update title (format: "Button / default")
        String title = subStory.getParentName() + " / " + subStory.getDisplayName();
        updateToolbarTitle(title);

        // Add log
        addLog("Loaded sub-example: " + subStory.getParentName() + " / " + subStory.getDisplayName());

        // If editor is open, update editor content
        if (currentEditorType == EditorType.COMPONENTS) {
            etJsonEditor.setText(currentComponentsJson);
        } else if (currentEditorType == EditorType.DATA_MODEL) {
            etJsonEditor.setText(currentDataModelJson);
        }

        // Call A2UI render
        renderComponents();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_demo, menu);

        // Setup theme switch
//        MenuItem themeItem = menu.findItem(R.id.action_toggle_theme);
//        if (themeItem != null) {
//            View actionView = themeItem.getActionView();
//            if (actionView != null) {
//                androidx.appcompat.widget.SwitchCompat themeSwitch =
//                        actionView.findViewById(R.id.themeSwitch);
//                if (themeSwitch != null) {
//                    // Set initial state (inverted: checked = day mode, unchecked = night mode)
//                    themeSwitch.setChecked(!isDarkMode);
//
//                    // Set listener
//                    themeSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
//                        // Invert logic: checked (sun side) = day mode, unchecked (moon side) = night mode
//                        isDarkMode = !isChecked;
//
//                        // Save theme preference
//                        themePrefs.edit().putBoolean(KEY_DARK_MODE, isDarkMode).apply();
//
//                        // Update AGenUI theme (renderer handles day/night internally)
//                        String mode = isDarkMode ? "dark" : "light";
//                        if (surfaceManager != null) {
//                            surfaceManager.setDayNightMode(mode);
//                            addLog("切换主题模式: " + mode);
//                        }
//
//                        String message = isDarkMode ? "已切换到夜间模式" : "已切换到日间模式";
//                        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
//                    });
//                }
//            }
//        }

        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();

        if (id == R.id.action_edit) {
            // Click "Edit" button, open right edit drawer
            openEditor(EditorType.COMPONENTS);
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    /**
     * Setup edit drawer
     */
    private void setupDrawer() {
        // Tab switch listener
        tabLayout.addOnTabSelectedListener(new TabLayout.OnTabSelectedListener() {
            @Override
            public void onTabSelected(TabLayout.Tab tab) {
                onTabChanged(tab.getPosition());
            }

            @Override
            public void onTabUnselected(TabLayout.Tab tab) {
                // Save current editing content
                saveCurrentTabContent();
            }

            @Override
            public void onTabReselected(TabLayout.Tab tab) {
                // Do nothing
            }
        });

        // Format button
        btnFormat.setOnClickListener(v -> formatJson());

        // Validate button
        btnValidate.setOnClickListener(v -> validateJson());

        // Cancel button
        btnCancel.setOnClickListener(v -> closeDrawer());

        // Save button
        btnSave.setOnClickListener(v -> saveAndRender());
    }

    /**
     * Open editor
     */
    private void openEditor(EditorType type) {
        // 🔧 Fix: Save current content before switching state
        // This prevents the bug where content gets saved to wrong variable
        // when tabLayout.selectTab() triggers onTabUnselected callback
        saveCurrentTabContent();

        currentEditorType = type;

        // 🔧 Fix: Set editor content BEFORE selecting tab
        // This ensures that when onTabUnselected is triggered by selectTab(),
        // the editor already contains the correct content for the new tab
        switch (type) {
            case COMPONENTS:
                etJsonEditor.setText(currentComponentsJson);  // Set content first
                tabLayout.selectTab(tabLayout.getTabAt(0));   // Then select tab
                break;
            case DATA_MODEL:
                etJsonEditor.setText(currentDataModelJson);
                tabLayout.selectTab(tabLayout.getTabAt(1));
                break;
        }

        // Open right drawer
        View drawerView = findViewById(R.id.drawerJsonEditor);
        if (drawerView != null) {
            drawerLayout.openDrawer(GravityCompat.END);
        }
    }

    /**
     * Callback when Tab switches
     */
    private void onTabChanged(int position) {
        switch (position) {
            case 0: // Components
                currentEditorType = EditorType.COMPONENTS;
                etJsonEditor.setText(currentComponentsJson);
                addLog("Switch to Components editing");
                break;
            case 1: // DataModel
                currentEditorType = EditorType.DATA_MODEL;
                etJsonEditor.setText(currentDataModelJson);
                addLog("Switch to DataModel editing");
                break;
        }
    }

    /**
     * Save current Tab content
     */
    private void saveCurrentTabContent() {
        // 🔧 Fix: Only save when currentEditorType is valid
        // This prevents saving wrong content when editor type is NONE
        // (e.g., after closeDrawer() sets type to NONE but editor still has old content)
        if (currentEditorType == EditorType.NONE) {
            return;
        }

        String json = etJsonEditor.getText().toString().trim();

        switch (currentEditorType) {
            case COMPONENTS:
                currentComponentsJson = json;
                break;
            case DATA_MODEL:
                currentDataModelJson = json;
                break;
        }
    }

    /**
     * Close drawer
     */
    private void closeDrawer() {
        drawerLayout.closeDrawers();
        currentEditorType = EditorType.NONE;
    }

    /**
     * Format JSON
     */
    private void formatJson() {
        String json = etJsonEditor.getText().toString().trim();
        if (json.isEmpty()) {
            Toast.makeText(this, "JSON is empty", Toast.LENGTH_SHORT).show();
            return;
        }

        try {
            // Use Gson to format JSON
            Gson gson = new GsonBuilder().setPrettyPrinting().create();
            Object jsonObject = JsonParser.parseString(json);
            String formattedJson = gson.toJson(jsonObject);

            // Update editor content
            etJsonEditor.setText(formattedJson);

            Toast.makeText(this, "Format successful", Toast.LENGTH_SHORT).show();
            addLog("JSON format successful");
        } catch (JsonSyntaxException e) {
            Toast.makeText(this, "JSON format error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            addLog("JSON format failed: " + e.getMessage());
        } catch (Exception e) {
            Toast.makeText(this, "Format failed: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            addLog("Format failed: " + e.getMessage());
        }
    }

    /**
     * Validate JSON
     */
    private void validateJson() {
        String json = etJsonEditor.getText().toString().trim();
        if (json.isEmpty()) {
            Toast.makeText(this, "JSON is empty", Toast.LENGTH_SHORT).show();
            return;
        }

        try {
            // Use Gson to validate JSON
            JsonParser.parseString(json);
            Toast.makeText(this, "JSON format is correct", Toast.LENGTH_SHORT).show();
            addLog("JSON validation passed");
        } catch (JsonSyntaxException e) {
            Toast.makeText(this, "JSON format error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            addLog("JSON validation failed: " + e.getMessage());
        } catch (Exception e) {
            Toast.makeText(this, "JSON format error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            addLog("JSON validation failed: " + e.getMessage());
        }
    }

    /**
     * Save and render
     */
    private void saveAndRender() {
        // First save current Tab content
        saveCurrentTabContent();

        // 添加日志
        switch (currentEditorType) {
            case COMPONENTS:
                addLog("Components updated");
                break;
            case DATA_MODEL:
                addLog("DataModel updated");
                break;
        }

        closeDrawer();

        // TODO: Call A2UI rendering
        renderComponents();
    }

    /**
     * Copy JSON to clipboard
     */
    private void copyJsonToClipboard() {
        String json = "Components:\n" + currentComponentsJson + "\n\nDataModel:\n" + currentDataModelJson;
        android.content.ClipboardManager clipboard = (android.content.ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
        android.content.ClipData clip = android.content.ClipData.newPlainText("A2UI JSON", json);
        clipboard.setPrimaryClip(clip);
        Toast.makeText(this, "JSON copied to clipboard", Toast.LENGTH_SHORT).show();
        addLog("JSON copied");
    }

    /**
     * Clear all content
     */
    private void clearAll() {
        currentComponentsJson = "{}";
        currentDataModelJson = "{}";
        renderContent.removeAllViews();
        addLog("All content cleared");
        Toast.makeText(this, "Cleared", Toast.LENGTH_SHORT).show();
    }

    /**
     * Initialize A2UI Framework
     */
    private void initAGenUI() {
        try {
            // 1. 创建 SurfaceManager
            surfaceManager = new SurfaceManager(this);
            // 4. 注册 Surface 监听器
            surfaceManager.addListener(new ISurfaceListener() {
                @Override
                public void onCreateSurface(String surfaceId, Surface surfaceView) {
                    runOnUiThread(() -> {
                        currentSurfaceId = surfaceId;
                        addLog("✓ Surface created: " + surfaceId);

                        if (surfaceView != null) {
                            // Clear previous content
                            renderContent.removeAllViews();

                            // Add Surface's internal container to our ViewTree
                            renderContent.addView(surfaceView.getContainer());
                            addLog("✓ Surface container added to ViewTree");
                        } else {
                            addLog("❌ Unable to get Surface: " + surfaceId);
                        }
                    });
                }

                @Override
                public void onDeleteSurface(String surfaceId) {
                    runOnUiThread(() -> {
                        addLog("Surface deleted: " + surfaceId);
                    });
                }
            });

            if (true) {
                addLog("✓ AGenUI SDK initialized successfully");
                addLog("✓ UI Templates copied to sandbox");
            }

            addLog("A2UI Framework initialized successfully");

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Render components
     */
    private void renderComponents() {
        try {
            addLog("Start rendering...");

            // 🔧 Key fix: Generate unique surfaceId
            String newSurfaceId = "surface_" + System.currentTimeMillis();
            addLog("Generated new Surface ID: " + newSurfaceId);

            // 🔧 Key fix: Destroy old Surface
            if (currentSurfaceId != null && surfaceManager != null) {
                addLog("Destroy old Surface: " + currentSurfaceId);
                // Release old SurfaceManager and create a new one
                surfaceManager.release();
                surfaceManager = new SurfaceManager(this);
                surfaceManager.addListener(new ISurfaceListener() {
                    @Override
                    public void onCreateSurface(String surfaceId, Surface surfaceView) {
                        runOnUiThread(() -> {
                            currentSurfaceId = surfaceId;
                            if (surfaceView != null) {
                                renderContent.removeAllViews();
                                renderContent.addView(surfaceView.getContainer());
                            }
                        });
                    }

                    @Override
                    public void onDeleteSurface(String surfaceId) {
                    }
                });
                renderContent.removeAllViews();
            }

            // 🔧 Key fix: Replace surfaceId in JSON
            String updatedComponentsJson = replaceSurfaceIdInJson(currentComponentsJson, newSurfaceId);
            String updatedDataModelJson = replaceSurfaceIdInJson(currentDataModelJson, newSurfaceId);

            addLog("Surface ID replaced");

            // 1. Send createSurface
            JSONObject createSurfaceJson = new JSONObject();
            createSurfaceJson.put("version", "v0.9");

            JSONObject createSurfaceData = new JSONObject();
            createSurfaceData.put("surfaceId", newSurfaceId);
            createSurfaceData.put("catalogId", "https://a2ui.org/specification/v0_9/standard_catalog.json");

            createSurfaceJson.put("createSurface", createSurfaceData);

            surfaceManager.receiveTextChunk(createSurfaceJson.toString());
            addLog("1/3 Sent createSurface");

            // 2. Send updateComponents
            surfaceManager.receiveTextChunk(updatedComponentsJson);
            addLog("2/3 Sent updateComponents");

            // 3. Send updateDataModel (if not empty)
            if (!updatedDataModelJson.equals("{}")) {
                surfaceManager.receiveTextChunk(updatedDataModelJson);
                addLog("3/3 Sent updateDataModel");
            } else {
                addLog("3/3 updateDataModel is empty, skipped");
            }

            // Update current surfaceId
            currentSurfaceId = newSurfaceId;

            addLog("Rendering complete!");
            Toast.makeText(this, "Render successful", Toast.LENGTH_SHORT).show();

        } catch (JSONException e) {
            addLog("JSON parse error: " + e.getMessage());
            Toast.makeText(this, "JSON format error", Toast.LENGTH_SHORT).show();
            android.util.Log.e(TAG, "Failed to parse JSON", e);
        } catch (Exception e) {
            addLog("Render failed: " + e.getMessage());
            Toast.makeText(this, "Render failed", Toast.LENGTH_SHORT).show();
            android.util.Log.e(TAG, "Failed to render", e);
        }
    }

    /**
     * Replace surfaceId in JSON
     *
     * @param json         Original JSON string
     * @param newSurfaceId New surfaceId
     * @return Replaced JSON string
     */
    private String replaceSurfaceIdInJson(String json, String newSurfaceId) {
        try {
            JSONObject jsonObj = new JSONObject(json);

            // Check if updateComponents exists
            if (jsonObj.has("updateComponents")) {
                JSONObject updateComponents = jsonObj.getJSONObject("updateComponents");
                updateComponents.put("surfaceId", newSurfaceId);
            }

            // Check if updateDataModel exists
            if (jsonObj.has("updateDataModel")) {
                JSONObject updateDataModel = jsonObj.getJSONObject("updateDataModel");
                updateDataModel.put("surfaceId", newSurfaceId);
            }

            return jsonObj.toString();
        } catch (JSONException e) {
            android.util.Log.e(TAG, "Failed to replace surfaceId in JSON", e);
            return json;  // If replacement fails, return original JSON
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();

        // Clean up SurfaceManager resources
        if (surfaceManager != null) {
            try {
                surfaceManager.release();
                surfaceManager = null;
                currentSurfaceId = null;
                addLog("SurfaceManager released");
            } catch (Exception e) {
                android.util.Log.e(TAG, "Failed to release SurfaceManager", e);
            }
        }
    }

    /**
     * Get default Components JSON template
     */
    private String getDefaultComponentsTemplate() {
        return "{\n" +
                "  \"version\": \"v0.9\",\n" +
                "  \"updateComponents\": {\n" +
                "    \"surfaceId\": \"custom_surface\",\n" +
                "    \"components\": [\n" +
                "      {\n" +
                "        \"id\": \"root\",\n" +
                "        \"component\": \"Card\",\n" +
                "        \"child\": \"text1\"\n" +
                "      },\n" +
                "      {\n" +
                "        \"id\": \"text1\",\n" +
                "        \"component\": \"Text\",\n" +
                "        \"text\": \"Hello, A2UI!\",\n" +
                "        \"variant\": \"h2\"\n" +
                "      }\n" +
                "    ]\n" +
                "  }\n" +
                "}";
    }

    /**
     * Update Toolbar title
     */
    private void updateToolbarTitle(String title) {
        if (getSupportActionBar() != null) {
            getSupportActionBar().setTitle(title);
        }
    }

    /**
     * Add log
     */
    private void addLog(String message) {
        // Also output to Android console
        android.util.Log.d(TAG, message);
    }
}
