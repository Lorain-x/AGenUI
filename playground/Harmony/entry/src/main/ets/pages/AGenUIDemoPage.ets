import { resourceManager } from '@kit.LocalizationKit';
import { JSON } from '@kit.ArkTS';
import util from '@ohos.util';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AGenUIContainer, SurfaceManager, ISurfaceListener } from '@agenui/agenui';

import { copyRawfileDirToSandbox } from '../utils/ResourceCopyUtil';



const TAG = 'Index';
const DOMAIN = 0x0000;

class SurfaceListenerImpl implements ISurfaceListener{
  private indexComponent: Index | null = null;

  constructor(indexComponent: Index) {
    this.indexComponent = indexComponent;
  }

  onCreateSurface(surfaceId: string): void {
    hilog.info(0x0000, 'AGenUI', `Surface created successfully: ${surfaceId}`);
    // Further operations can be performed here, e.g. binding Surface to UI
    if (this.indexComponent) {
      this.indexComponent.addAGenUIContainer(surfaceId);
    }
  }

  onDeleteSurface(surfaceId: string): void {
    hilog.info(0x0000, 'AGenUI', `Surface destroyed: ${surfaceId}`);
    // Cleanup operations can be performed here
    if (this.indexComponent) {
      this.indexComponent.removeAGenUIContainer(surfaceId);
    }
  }

}


// Menu item data structure
interface MenuItem {
  name: string;
  path: string;
  children?: MenuItem[];
  isExpanded?: boolean;
}

// UpdateComponents data structure
interface UpdateComponentsData {
  surfaceId?: string;
  components?: Array<Record<string, ESObject>>;
}

// Components JSON data structure
interface ComponentsData {
  version?: string;
  updateComponents?: UpdateComponentsData;
}

@Entry
@Component
struct Index {
  @State menuItems: MenuItem[] = [];
  @State currentContent: string = '';
  @State currentTitle: string = 'Feature Menu';
  @State isDrawerOpen: boolean = false;
  @State isEditorOpen: boolean = false;
  @State editorContent: string = '';
  @State currentTabIndex: number = 0; // 0: Components, 1: DataModel
  @State componentsJson: string = '{}';
  @State dataModelJson: string = '{}';
  @State currentSurfaceId: string = ''; // Controls the display of AGenUIContainer and its surfaceId
  @State surfaceVersion: number = 0; // Incrementing version number used to force component rebuild in ForEach key
  @State isDarkMode: boolean = false; // Day/Night mode

  private surfaceManager: SurfaceManager | null = null;

  onDidBuild(): void {
    AppStorage.setOrCreate<UIContext>('context', this.getUIContext());
  }

  aboutToAppear() {
    // 1. Copy resources from rawfile to sandbox and initialize the SDK
    const context = getContext(this) as common.UIAbilityContext;
    this.surfaceManager = new SurfaceManager(context);
    this.surfaceManager.addListener(new SurfaceListenerImpl(this));
    this.loadFilesFromRawFiles(context);
    this.loadStoriesFromRawfile();
  }

  // Add AGenUIContainer
  addAGenUIContainer(surfaceId: string) {
    hilog.info(DOMAIN, TAG, 'Add AGenUIContainer, surfaceId: %{public}s', surfaceId);
    this.surfaceVersion++;
    this.currentSurfaceId = surfaceId;
  }

  // Remove AGenUIContainer
  removeAGenUIContainer(surfaceId: string) {
    hilog.info(DOMAIN, TAG, 'Remove AGenUIContainer, surfaceId: %{public}s', surfaceId);
    if (this.currentSurfaceId === surfaceId) {
      this.currentSurfaceId = '';
    }
  }

  async loadFilesFromRawFiles(context: common.UIAbilityContext) {
    Promise.all([
      copyRawfileDirToSandbox(context, 'ui_templates', 'data/ui_templates'),
      copyRawfileDirToSandbox(context, 'icons', 'data/icons'),
    ])
      .then((results: string[]) => {
        const uiTemplatesPath: string = results[0];
        const iconsPath: string = results[1];
        hilog.info(DOMAIN, TAG, 'ui_templates copied to sandbox: %{public}s', uiTemplatesPath);
        hilog.info(DOMAIN, TAG, 'icons copied to sandbox: %{public}s', iconsPath);
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'Failed to copy resources to sandbox: %{public}s', JSON.stringify(err));
      });
  }

  async loadStoriesFromRawfile() {
    try {
      const resMgr = getContext(this).resourceManager;
      const storiesPath = 'stories';

      hilog.info(DOMAIN, TAG, 'Start loading stories directory');

      // Read first-level directories under stories
      const firstLevelDirs = await this.readDirectory(resMgr, storiesPath);
      hilog.info(DOMAIN, TAG, `Found ${firstLevelDirs.length} first-level directories`);

      const menuItems: MenuItem[] = [];

      // Iterate first-level directories
      for (const firstDir of firstLevelDirs) {
        // Skip hidden files
        if (firstDir.startsWith('.')) {
          continue;
        }

        const firstLevelPath = `${storiesPath}/${firstDir}`;
        hilog.info(DOMAIN, TAG, `Reading first-level directory: ${firstDir}`);

        // Read second-level directories
        const secondLevelDirs = await this.readDirectory(resMgr, firstLevelPath);
        hilog.info(DOMAIN, TAG, `  Found ${secondLevelDirs.length} second-level directories`);

        const children: MenuItem[] = [];

        // Iterate second-level directories
        for (const secondDir of secondLevelDirs) {
          // Skip hidden files
          if (secondDir.startsWith('.')) {
            continue;
          }

          const secondLevelPath = `${firstLevelPath}/${secondDir}`;
          hilog.info(DOMAIN, TAG, `  Reading second-level directory: ${secondDir}`);

          // Read JSON files under the second-level directory
          const jsonFiles = await this.readDirectory(resMgr, secondLevelPath);
          hilog.info(DOMAIN, TAG, `    Found ${jsonFiles.length} files`);

          // Check whether JSON files exist
          const hasJsonFiles = jsonFiles.some(file => file.endsWith('.json'));
          if (hasJsonFiles) {
            // Only add the second-level directory name, not the specific JSON file names
            children.push({
              name: secondDir,
              path: secondLevelPath,
              isExpanded: false
            });
          }
        }

        if (children.length > 0) {
          menuItems.push({
            name: firstDir,
            path: firstLevelPath,
            children: children,
            isExpanded: false
          });
        }
      }

      this.menuItems = menuItems;
      hilog.info(DOMAIN, TAG, `Loading complete, ${menuItems.length} first-level menu items in total`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load stories: %{public}s', JSON.stringify(error));
      console.error('Failed to load stories:', JSON.stringify(error));
    }
  }

  // Read directory contents
  async readDirectory(resMgr: resourceManager.ResourceManager, path: string): Promise<string[]> {
    try {
      const fileList = await resMgr.getRawFileList(path);
      return fileList;
    } catch (error) {
      console.error(`Failed to read directory ${path}:`, JSON.stringify(error));
      return [];
    }
  }

  // Apply theme mode: synchronously update the App-level system color mode + AGenUI content area theme
  applyThemeMode(isDark: boolean) {
    const mode = isDark ? 'dark' : 'light';
    hilog.info(DOMAIN, TAG, 'Switching theme mode: %{public}s', mode);

    // 1. Modify the App-level system color mode (affects all ArkUI native components)
    try {
      const colorMode = isDark
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      getContext(this).getApplicationContext().setColorMode(colorMode);
      hilog.info(DOMAIN, TAG, 'App setColorMode called with: %{public}s', mode);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setColorMode failed: %{public}s', JSON.stringify(err));
    }

    // 2. Set the AGenUI content area theme mode
    this.surfaceManager!.setDayNightMode(mode);
    hilog.info(DOMAIN, TAG, 'setThemeMode called with: %{public}s', mode);
  }

  // Toggle first-level menu expand state
  toggleFirstLevel(index: number) {
    // Create a new array to trigger UI update
    const newMenuItems = [...this.menuItems];
    newMenuItems[index].isExpanded = !newMenuItems[index].isExpanded;
    this.menuItems = newMenuItems;
  }

  // Decode raw byte data and format it as a JSON string
  private decodeAndFormatJson(rawData: Uint8Array): string {
    const decoder = util.TextDecoder.create('utf-8');
    const rawJson = decoder.decodeWithStream(rawData);
    const jsonObj = JSON.parse(rawJson) as object;
    return JSON.stringify(jsonObj, null, 2);
  }

  // Click on a second-level menu item
  async selectSecondLevel(firstIndex: number, secondIndex: number) {
    const item = this.menuItems[firstIndex].children![secondIndex];
    this.currentTitle = `${this.menuItems[firstIndex].name} / ${item.name}`;
    this.isDrawerOpen = false;

    const resMgr = getContext(this).resourceManager;

    // Load Components JSON (fall back to empty object if file does not exist)
    try {
      const componentsRawData = await resMgr.getRawFileContent(`${item.path}/updateComponents.json`);
      this.componentsJson = this.decodeAndFormatJson(componentsRawData);
      hilog.info(DOMAIN, TAG, 'Successfully loaded Components JSON, path: %{public}s', item.path);
    } catch (e) {
      this.componentsJson = '{}';
      hilog.info(DOMAIN, TAG, 'Components file does not exist, using empty object');
    }

    // Load DataModel JSON (fall back to empty object if file does not exist)
    try {
      const dataModelRawData = await resMgr.getRawFileContent(`${item.path}/updateDataModel.json`);
      this.dataModelJson = this.decodeAndFormatJson(dataModelRawData);
      hilog.info(DOMAIN, TAG, 'Successfully loaded DataModel JSON, path: %{public}s', item.path);
    } catch (e) {
      this.dataModelJson = '{}';
      hilog.info(DOMAIN, TAG, 'DataModel file does not exist, using empty object');
    }

    // Extract surfaceId from componentsJson
    const componentsObj = JSON.parse(this.componentsJson) as ComponentsData;
    const newSurfaceId = componentsObj.updateComponents?.surfaceId ?? 'default_surface';
    hilog.info(DOMAIN, TAG, 'Extracted surfaceId: %{public}s', newSurfaceId);

    // If there is an active Surface: first clear the container to trigger unbindSurface, then send deleteSurface to destroy the old Surface
    if (this.currentSurfaceId) {
      const oldSurfaceId = this.currentSurfaceId;
      const deleteSurfaceJsonStr = `{"version":"v0.9","deleteSurface":{"surfaceId":"${oldSurfaceId}"}}`;
      this.surfaceManager!.receiveTextChunk(deleteSurfaceJsonStr);
      hilog.info(DOMAIN, TAG, '0/3 deleteSurface sent (destroying old Surface): %{public}s', oldSurfaceId);
    }

    // Send createSurface (C++ side creates Surface, which then triggers the onCreateSurface callback)
    const createSurfaceJsonStr = `{"version":"v0.9","createSurface":{"surfaceId":"${newSurfaceId}","catalogId":"https://a2ui.org/specification/v0_9/standard_catalog.json"}}`;
    this.surfaceManager!.receiveTextChunk(createSurfaceJsonStr);
    hilog.info(DOMAIN, TAG, '1/3 createSurface sent: %{public}s', newSurfaceId);

    // Immediately update editor content display without waiting for C++ rendering to complete
    this.currentContent = `Components:\n${this.componentsJson}\n\nDataModel:\n${this.dataModelJson}`;

    this.surfaceManager!.receiveTextChunk(this.componentsJson);
    hilog.info(DOMAIN, TAG, '2/3 updateComponents sent');

    // Skip when updateDataModel is empty to avoid C++ parsing an empty JSON
    if (this.dataModelJson !== '{}') {
      this.surfaceManager!.receiveTextChunk(this.dataModelJson);
      hilog.info(DOMAIN, TAG, '3/3 updateDataModel sent');
    }
  }

  // Toggle sidebar
  toggleDrawer() {
    this.isDrawerOpen = !this.isDrawerOpen;
  }

  // Open editor
  openEditor() {
    this.currentTabIndex = 0;
    this.editorContent = this.componentsJson;
    this.isEditorOpen = true;
  }

  // Close editor
  closeEditor() {
    this.isEditorOpen = false;
  }

  // Switch Tab
  switchTab(index: number) {
    // Save the content of the current Tab
    if (this.currentTabIndex === 0) {
      this.componentsJson = this.editorContent;
    } else {
      this.dataModelJson = this.editorContent;
    }

    // Switch to the new Tab
    this.currentTabIndex = index;
    this.editorContent = index === 0 ? this.componentsJson : this.dataModelJson;
  }

  // Format JSON
  formatJson() {
    try {
      const jsonObj = JSON.parse(this.editorContent);
      this.editorContent = JSON.stringify(jsonObj, null, 2);
      hilog.info(DOMAIN, TAG, 'JSON formatted successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'JSON formatting failed: %{public}s', error.message);
    }
  }

  // Validate JSON
  validateJson() {
    try {
      JSON.parse(this.editorContent);
      hilog.info(DOMAIN, TAG, 'JSON validation passed');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'JSON validation failed: %{public}s', error.message);
    }
  }

  // Save and preview
  saveAndPreview() {
    // Save the content of the current Tab
    if (this.currentTabIndex === 0) {
      this.componentsJson = this.editorContent;
    } else {
      this.dataModelJson = this.editorContent;
    }

    hilog.info(DOMAIN, TAG, 'Saved successfully');
    this.closeEditor();

    // TODO: Invoke rendering logic
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Main content area
      Column() {
        // Top title bar
        Row() {
          Image($r('app.media.ic_menu'))
            .width(24)
            .height(24)
            .margin({ left: 16 })
            .onClick(() => {
              this.toggleDrawer();
            })

          Text(this.currentTitle)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .margin({ left: 16 })
            .layoutWeight(1)

          // Day/Night mode toggle
          Row() {
            Text(this.isDarkMode ? '🌙' : '☀️')
              .fontSize(14)
              .fontColor(Color.White)
              .margin({ right: 4 })
            Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
              .width(40)
              .height(22)
              .selectedColor('#4D95E5')
              .onChange((isOn: boolean) => {
                this.isDarkMode = isOn;
                this.applyThemeMode(isOn);
              })
          }
          .margin({ right: 12 })
          .alignItems(VerticalAlign.Center)

          Text('Edit')
            .fontSize(16)
            .fontColor(Color.White)
            .margin({ right: 16 })
            .onClick(() => {
              this.openEditor();
            })
        }
        .width('100%')
        .height(56)
        .backgroundColor(this.isDarkMode ? '#3700B3' : '#6200EE')
        .alignItems(VerticalAlign.Center)

        // A2UI native rendering area (wrapped in Scroll to support scrolling)
        Scroll() {
          Column() {
            ForEach(
              this.currentSurfaceId ? [this.currentSurfaceId] : [],
              (surfaceId: string) => {
                AGenUIContainer({ surfaceId: surfaceId })
                  .backgroundColor(this.isDarkMode ? '#121212' : '#FFFFFF')
                  .width('100%')
              },
              (_surfaceId: string) => `agenui_${this.surfaceVersion}`
            )
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .align(Alignment.Top)
        .backgroundColor(this.isDarkMode ? '#121212' : '#FFFFFF')
      }
      .width('100%')
      .height('100%')

      // Sidebar menu
      if (this.isDrawerOpen) {
        Row() {
          // Menu content
          Column() {
            // Menu title
            Row() {
              Text('Feature Menu')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ left: 16 })
            }
            .width('100%')
            .height(56)
            .backgroundColor(this.isDarkMode ? '#3700B3' : '#6200EE')
            .alignItems(VerticalAlign.Center)

            // Custom component area
            Column() {
              Row() {
                Image($r('app.media.ic_add'))
                  .width(24)
                  .height(24)
                  .fillColor('#4CAF50')
                  .margin({ left: 16, right: 12 })

                Column() {
                  Text('Custom Component')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isDarkMode ? '#E0E0E0' : '#000000')

                  Text('Manually enter JSON to create a component')
                    .fontSize(14)
                    .fontColor(this.isDarkMode ? '#AAAAAA' : '#666666')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ top: 16, bottom: 16 })
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)

            Divider()
              .height(1)
              .color(this.isDarkMode ? '#333333' : '#E0E0E0')

            // Menu list
            Scroll() {
              Column() {
                ForEach(this.menuItems, (item: MenuItem, firstIndex: number) => {
                  Column() {
                    // First-level menu
                    Row() {
                      Text(item.name)
                        .fontSize(18)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.isDarkMode ? '#E0E0E0' : '#000000')
                        .layoutWeight(1)

                      Image(item.isExpanded ? $r('app.media.ic_expand_less') : $r('app.media.ic_expand_more'))
                        .width(24)
                        .height(24)
                        .fillColor(this.isDarkMode ? '#AAAAAA' : '#666666')
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
                    .onClick(() => {
                      this.toggleFirstLevel(firstIndex);
                    })

                    // Second-level menu
                    if (item.isExpanded && item.children) {
                      Column() {
                        ForEach(item.children, (child: MenuItem, secondIndex: number) => {
                          Row() {
                            Text(child.name)
                              .fontSize(16)
                              .fontColor(this.isDarkMode ? '#BBBBBB' : '#333333')
                              .padding({ left: 40, top: 12, bottom: 12 })
                          }
                          .width('100%')
                          .onClick(() => {
                            this.selectSecondLevel(firstIndex, secondIndex);
                          })
                        })
                      }
                      .width('100%')
                      .backgroundColor(this.isDarkMode ? '#2A2A2A' : '#F8F8F8')
                    }
                  }
                  .width('100%')
                })
              }
              .width('100%')
            }
            .layoutWeight(1)
            .width('100%')
            .align(Alignment.Top)
            .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
          }
          .width('68%')
          .height('100%')
          .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)

          // Semi-transparent overlay
          Column()
            .layoutWeight(1)
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.isDrawerOpen = false;
            })
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }

      // JSON editor panel (slides in from the right, occupies 68%)
      if (this.isEditorOpen) {
        Row() {
          // Semi-transparent overlay
          Column()
            .layoutWeight(1)
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.closeEditor();
            })

          // Editor content
          Column() {
            // Editor title bar
            Row() {
              Image($r('app.media.ic_menu'))
                .width(24)
                .height(24)
                .margin({ left: 16 })
                .onClick(() => {
                  this.closeEditor();
                })

              Text('JSON Editor')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ left: 16 })
                .layoutWeight(1)
            }
            .width('100%')
            .height(56)
            .backgroundColor(this.isDarkMode ? '#3700B3' : '#6200EE')
            .alignItems(VerticalAlign.Center)

            // Tab switcher
            Row() {
              Text('COMPONENTS')
                .fontSize(14)
                .fontWeight(this.currentTabIndex === 0 ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.currentTabIndex === 0 ? '#BB86FC' : (this.isDarkMode ? '#AAAAAA' : '#666666'))
                .padding({ left: 24, right: 24, top: 12, bottom: 12 })
                .onClick(() => {
                  this.switchTab(0);
                })

              Text('DATAMODEL')
                .fontSize(14)
                .fontWeight(this.currentTabIndex === 1 ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.currentTabIndex === 1 ? '#BB86FC' : (this.isDarkMode ? '#AAAAAA' : '#666666'))
                .padding({ left: 24, right: 24, top: 12, bottom: 12 })
                .onClick(() => {
                  this.switchTab(1);
                })
            }
            .width('100%')
            .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)

            Divider()
              .height(2)
              .color(this.currentTabIndex === 0 ? '#BB86FC' : Color.Transparent)
              .margin({ left: this.currentTabIndex === 0 ? 0 : 120 })
              .width(this.currentTabIndex === 0 ? 120 : 120)

            // JSON editing area
            Scroll() {
              TextArea({ text: this.editorContent })
                .width('100%')
                .height('100%')
                .backgroundColor(this.isDarkMode ? '#2A2A2A' : '#F5F5F5')
                .fontSize(12)
                .fontColor(this.isDarkMode ? '#E0E0E0' : '#000000')
                .fontFamily('monospace')
                .padding(16)
                .onChange((value: string) => {
                  this.editorContent = value;
                })
            }
            .layoutWeight(1)
            .width('100%')

            // Bottom button area
            Column() {
              Row() {
                Button('Format')
                  .fontSize(14)
                  .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
                  .fontColor('#BB86FC')
                  .borderWidth(1)
                  .borderColor('#BB86FC')
                  .layoutWeight(1)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.formatJson();
                  })

                Button('Validate')
                  .fontSize(14)
                  .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
                  .fontColor('#BB86FC')
                  .borderWidth(1)
                  .borderColor('#BB86FC')
                  .layoutWeight(1)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.validateJson();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 8 })

              Row() {
                Button('Cancel')
                  .fontSize(16)
                  .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
                  .fontColor(this.isDarkMode ? '#AAAAAA' : '#666666')
                  .layoutWeight(1)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.closeEditor();
                  })

                Button('Save & Preview')
                  .fontSize(14)
                  .backgroundColor(this.isDarkMode ? '#3700B3' : '#6200EE')
                  .fontColor(Color.White)
                  .layoutWeight(1)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.saveAndPreview();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 16 })
            }
            .width('100%')
            .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
          }
          .width('68%')
          .height('100%')
          .backgroundColor(this.isDarkMode ? '#1E1E1E' : Color.White)
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? '#121212' : '#FFFFFF')
  }
}
